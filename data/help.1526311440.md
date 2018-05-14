tags: help markdown cheatsheet
author: marc

# Special Headers
The first lines before a double linebreak are treated as header lines.
Pages start with at least one header automatically: `author: user`

Additional headers are:

* `author: <user>` indicates who last edited this page
* `tags: some space separated tags` helps the search
* `protected: tom bob @somegroup` allows only those to edit
* `private: @somegroup jim alice @another_group` allows only those to view

# Special Functions
This Wiki supports an internal special function engine.
Currently these functions are supported and can be used inside pages:

* `- =index=-` index of all pages
* `- =versions ARG=-` versions of pages matching ARG
* `- =partial ARG=-` embedds page ARG
* `- =embed ARG=-` embedds URl ARG as iframe
* `- =diff=-` renders a diff between the last versions of this page
* `- =time=-` current date and time

*note that the space between the hypen and the equal sign has to be removed*

---

# Markdown Cheatsheet
{:.no_toc}

* toc
{:toc}

---

## General

    #### This is an h4 tag
    ###### This is an h6 tag

#### This is an h4 tag
###### This is an h6 tag

    *This text will be italic*
    _This will also be italic_
    **This text will be bold**
    __This will also be bold__
    *You __can__ combine them*

*This text will be italic*
_This will also be italic_
**This text will be bold**
__This will also be bold__
*You __can__ combine them*

---

## Links

    [Reddit](http://reddit.com)

[Reddit](http://reddit.com)

---

## Images

    ![octo goodness](https://a248.e.akamai.net/assets.github.com/images/modules/dashboard/octofication.png)

![octo goodness](https://a248.e.akamai.net/assets.github.com/images/modules/dashboard/octofication.png)

---

## Lists

    * Item 1
    * Item 2
        1. Item 2a
        2. Item 2b
        3. Item 2c
    * and another one
        * with another subitem

* Item 1
* Item 2
  1. Item 2a
  2. Item 2b
    * xxx
  3. Item 2c

* blah
* and another one
  1. with another subitem

* blubber
  * blah

---

## Codeblocks
_start with 4 spaces_

        void main(){
            return -1;
        }

    void main(){
        return -1;
    }

---

## Blockquotes

    > We're living the future so
    > the present is our past.

> We're living the future so
> the present is our past.

---

## Custom styles

    [Reddit](http://reddit.com){: #myid .btn .btn-primary}

[Reddit](http://reddit.com){: #myid .btn .btn-primary}

---

## Footnotes

    * footnotes [^foot]

    [^foot]: I really was missing those.

* footnotes [^foot]

[^foot]: I really was missing those.

---

## Tables

    Col1 | Very very long head | Very very long head |
    -----|:-------------------:|-------------------:|
    cell1 | center-align    | right-align        |
    cell2 | one more        | one more        |
    {: .table .table-bordered .table-hover}

Col1 | Very very long head | Very very long head |
-----|:-------------------:|-------------------:|
cell1 | center-align    | right-align        |
cell2 | one more        | one more        |
{: .table .table-bordered .table-hover}


## Embedding stuff (special)

This is a specialty of this Wiki and has nothing to do with markdown.

Use ````-=func=-```` or ````-=func arg=-```` where func should be defined in the replacers method.

The following youtube video is embedded using ````embed```` as func and ````http://www.youtube.com/embed/SDnYMbYB-nU```` as arg

-=embed http://www.youtube.com/embed/SDnYMbYB-nU=-
