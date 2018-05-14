#pkill -f 'ruby niki.rb'
#nohup ruby niki.rb > /dev/null 2>&1 &
thin -p 4567 -d -P pid -e production -R config.ru start
