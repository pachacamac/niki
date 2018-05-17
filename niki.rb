#!/usr/bin/env ruby
DATADIR = (i=ARGV.index('--datadir')) ? ARGV.slice!(i,i+1)[1] : 'data' # hack to cope with Sinatras ARGV greediness
require 'sinatra'
require 'haml'
require 'kramdown'
require 'yaml/store'
#require 'byebug'
STDERR.reopen(File.new('access.log','a')).sync = true

class Niki < Sinatra::Base
  enable :inline_templates#, :logging, :dump_errors
  use Rack::Session::Cookie, key: 'rack.session', secret: 'your_secret'

  def initialize(opts={})
    super
    @logger   = opts.fetch(:logger, Logger.new(STDOUT))
    @datadir  = opts.fetch(:datadir, "#{File.absolute_path(File.dirname(__FILE__))}/data")
    FileUtils.mkdir_p(@datadir) unless File.exist?(@datadir)
    @userfile = opts.fetch(:userfile, "#{File.absolute_path(File.dirname(__FILE__))}/users.yml")
    @mountpath = opts.fetch(:mountpath, '/')
    #@mailopts = opts.fetch(:mailopts, nil) #required: from, pass. defaults to gmail settings
    #@salt     = opts.fetch(:salt, 'tRD0NpXX0APGaeZEca3KNXInEon7tzQ4ugaG')
  end

  def clean(name, fallback=nil, re=nil) # clean a name with a regexp
    name.tr(' ','_').match(re || /\w+/)[0] rescue fallback
  end

  def pages(name=nil, version=nil) # find matching files/versions
    Dir.glob("#{@datadir}/#{'.'if version}#{clean(name,'*')}.#{clean(version,'*')}.*")
  end

  def markdown_parts(s) # read markdown headers and body and convert headers to a hash
    lines = s.lines.to_a
    [{},''].tap do |a|
      a[0][$1.tr('-','_').to_sym] = $2.strip while (l=lines.shift) =~ /^(\w[\w\s\-]+): +(.*?)$/ # headers
      a[1] = ([l]+lines).join # anything else is the body
    end
  end

  def protect!(levels, headers=@headers, user=@user, groups=@groups) # keep out the unauthorized
    groups = (groups||[]).map{|g| "@#{g}"}
    levels.each{|l|
      next unless headers[l]
      names = headers[l].split.map(&:strip)
      throw(:halt, [401, "Not authorized - #{l}\n"]) if !names.include?(user) && (names&groups).empty?
    }
  end

  def replacers(s) # special replacers to add more dynamic to the wiki
    s.gsub(/-=index=-/){ @files = pages('*').map{|e| File.basename(e).split('.')[0]}.sort; haml(:list, layout: false) }
      .gsub(/-=versions (.*?)=-/){
        @files = pages($1,'*').map{|e|
          headers, content = markdown_parts(File.read(e))
          File.basename(e).split('.')[1,2] + [headers[:author]]
        }
        haml(:list, layout: false)
      }
      .gsub(/-=partial (.*?)=-/){
        h,c=markdown_parts(File.read(pages($1)[0]))
        protect!([:private],h)
        markdown(c, layout: false)
      }
      .gsub(/~~([^~]+?)~~/){"<del>#{$1}</del>"} # easy way to allow strikethrough
      .gsub(/-=embed (.*?)=-/){ %(<iframe src="#{URI.parse($1).to_s}" frameborder="0">&nbsp;</iframe>) }
      .gsub(/-=diff=-/){ # version diffs with wdiff if installed, otherwise with diff
        system("which wdiff > /dev/null 2>&1") ?
          %x{wdiff -w'<span class="diff-rem">' -x'</span>' -y'<span class="diff-add">' -z'</span>' #{pages(@page,@version).first} #{pages(@page).first}} :
          %x{diff -Bu #{pages(@page,@version).first} #{pages(@page).first}}
      }
      .gsub(/-=time=-/, Time.now.to_s) # you can simply add custom stuff like this
      .gsub(/-=uptime=-/, %x{uptime}.strip) # remember to keep it safe ;)
      #.gsub(/-=diff=-/){ %x{diff -Bu #{pages(@page,@version).first} #{pages(@page).first}} }
  end

  helpers{
    def to(uri); File.join(@mountpath, uri); end
  }

  configure{ set environment: :production, static: true}

  before{
    session.delete('init')
    @user = session['user']
    @groups = session['groups']
    content_type 'text/html', charset: 'utf-8'
  } # before every request

  get '/favicon.ico' do; end
  get '/' do redirect to('page/home') end

  get '/page/?:page?/?' do
    @page, @version = clean(params[:page], params.has_key?('edit') ? nil : 'home'), clean(params[:version])
    @raw_content = (@page ? (File.read(pages(@page,@version).first) rescue '') : '').gsub(/</, '&lt;') #xss protection?!
    @headers, @content = markdown_parts(replacers(@raw_content)) # replacer magic and header retrieval
    protect!([:private]) # if the page has a private field in the header, honor it
    haml (@content=='' || params.has_key?('edit')) ? :edit : :show
  end

  post '/page/?:page?/?' do # create or update a page .. yea not RESTful
    throw(:halt, [401, "Not logged in\n"]) unless @user # only users can play here
    FileUtils.mkdir_p(@datadir) unless File.exist?(@datadir) # create data dir
    params[:page] ||= params[:page_name]
    @page, time = clean(params[:page]), Time.now.to_i # pagename and version
    file = pages(@page).first || nil # edit or create?
    throw(:halt, [406, "Pagename invalid. (only a-zA-Z0-9_)\n"]) unless @page
    protect!([:protected, :private], markdown_parts(File.read(file))[0]) if file # check rights
    @headers, @content = markdown_parts(params[:content])
    FileUtils.copy(file, "#{@datadir}/.#{@page}.#{time}.md") if file # backup current to a version
    @headers = @headers.merge({author: @user}).map{|h| h.join(': ')}.join("\r\n") # overwrite author header
    merged_content = "#{@headers}\r\n\r\n#{@content}".gsub(/(\r\n){3,}/,"\r\n\r\n")
    File.write(file || "#{@datadir}/#{@page}.#{time}.md", merged_content)
    redirect to("page/#{@page}")
  end

  post '/?' do # user stuff and search
    if params[:q] # the search happens here. could be a GET but who cares?
      @files = (pages('*') + pages('*','*')).map do |f| # searching in latest and versions
        bnc = File.basename(f).split('.') # "basename components"
        name, version = bnc[0]=='' ? bnc[1,2] : [bnc[0], nil]
        hits = File.read(f).scan(/#{params[:q]}/i).size # magic search operation
        [name, version, "#{hits} hits"] if hits > 0
      end.compact.sort{|a,b| b.last.to_i<=>a.last.to_i} # throw out non hits and sort by hits
      @page = 'Search Results'; return haml :list
    end
    db = YAML::Store.new(@userfile) # User stuff happens here! login/logout/register
    (@user = session['user'] = session['groups'] = nil; return redirect(back)) if params[:logout] # that's the logout
    throw(:halt, [401, "Username invalid. (only a-zA-Z0-9_)\n"]) unless (clean_user = clean(params[:user])) # clean names only
    db.transaction{db['users'][clean_user] = Digest::SHA2.hexdigest(params[:pass]) unless db['users'][clean_user]} if params[:register] # register
    if db.transaction{db['users'][clean_user] == Digest::SHA2.hexdigest(params[:pass])}
      session['user'] = clean_user
      session['groups'] = db.transaction{ db['groups'].select{|k,v| v.include?(clean_user)}.keys }
      redirect(back) # successfully logged in
    else
      throw(:halt, [401, "Login invalid\n"]) # login failed
    end
  end
end

__END__
@@ layout
!!! 5
%html
  %head
    %title= @page ? "niki - #{@page}" : 'niki'
    %meta{name: "viewport", content: "width=device-width, initial-scale=1.0"}/
    %meta{'http-equiv' => 'Content-Type', content: 'text/html', charset: 'utf-8'}
    %meta{name: 'keywords', content: (@headers[:tags].split(/\W/).uniq.join(', ') rescue '')}
    %link{rel: 'shortcut icon', href: 'about:blank'}
    %link{rel: 'stylesheet', type: 'text/css', href: '//netdna.bootstrapcdn.com/twitter-bootstrap/2.2.1/css/bootstrap-combined.min.css'}
    :css
      * { padding:0; margin:0; border-box; box-sizing: border-box; }
      .container-narrow { margin: 40px auto; max-width: 820px; }
      textarea{ width: 99%; }
      iframe{ width: 99%; height:360px; }
      hr { border-top: 1px solid #e7e7e7; }
      .diff-rem { background-color: #f77; }
      .diff-add { background-color: #7f7; }
  %body
    .container-narrow
      %form.form-inline.pull-right{action: to(''), method: 'post'}
        %input.input-small{type: 'text', name: 'q', placeholder: 'search', required:''}
        %button.btn{type:'submit'} go
      %ul.nav.nav-pills.pull-right
        %li
          %a{href: to('page/home')}
            %i.icon-home
            home
        %li
          %a{href: to("page?edit")}
            %i.icon-plus
            new
        %li
          %a{href: to("page/#{@page}?edit#{"&version=#{@version}" if @version}")}
            %i.icon-pencil
            edit
      %h3.muted= @page || 'New Page'
      %hr
      = yield
      %hr
      %footer.muted
        &copy; The Open Source Community
        %form.form-inline.pull-right{action: to(''), method: 'post'}
          - if @user
            %button.btn.btn-link{type:'submit', name: 'logout', value: '1', title: "member of groups: #{@groups.join(', ')}"}&= "logout #{@user}"
          - else
            %input.input-small{type: 'text', name: 'user', placeholder: 'username', required:''}
            %input.input-small{type: 'password', name: 'pass', placeholder: 'password', required:''}
            %button.btn{type:'submit'} login
            %button.btn{type:'submit', name: 'register', value: '1'} register

@@ list
%ul.nav.nav-list
  - @files.each do |name, version, extra|
    %li
      %a{href: to("page/#{name}#{"?version=#{version}" if version}"), title: (Time.at(version.to_i).iso8601 if version)}= [name, version, extra].compact.join(' &ndash; ')

@@ show
.content
  = markdown @content
  %small.muted.pull-right= "last edited by #{@headers[:author]}"
- if @version
  %hr
  %h4 Diff with latest version
  %pre= replacers("-=diff=-")

@@ edit
%form{action: to("page/#{@page}"), method: 'post'}
  - unless @page
    %input{type: 'text', name: 'page_name', placeholder: 'page name', autofocus: '', required:''}
  %textarea{name: 'content', rows: '20', placeholder: 'page content in markdown', required:''}= @raw_content
  %small.muted.pull-right= "last edited by #{@headers[:author]}"
  %a.btn{href: to("#{@page ? "page/#{@page}" : 'page'}")} back
  %input.btn.btn-primary{type: 'submit', value: 'save'}
- if @page
  - if @version
    %hr
    %h4 Diff with latest version
    %pre= replacers("-=diff=-")
  %h4 Versions of this page:
  = replacers("-=versions #{@page}=-")
