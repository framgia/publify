# Framgia Publify

**The Ruby on Rails publishing software formerly known as Typo**

### Download

You can [clone Framgia Publify
repository](https://github.com/framgia/publify.git).

## What's Publify?

Publify is a simple but full featured web publishing software. It's built around a blogging engine and a small message system connected to Twitter.

Publify follows the principles of the IndieWeb, which are self hosting your Web site, and Publish On your Own Site, Syndicate Everywhere.

Publify has been around since 2004 and is the oldest Ruby on Rails open source project alive.

## Features

- A classic multi user blogging engine
- Short messages with a Twitter connection
- Text filters (Markdown, Textile, SmartyPants, @mention to link, #hashtag to link)
- A widgets system and a plugin API
- Custom themes
- Advanced SEO capabilities
- Multilingual : Publify is (more or less) translated in English, French, German, Danish, Norwegian, Japanese, Hebrew, Simplified Chinese, Mexican Spanish, Italian, Lithuanian, Dutch, Polish, Romanian…

## Install Publify  locally

To install Publify you need the following:

-   Ruby 2.1.4
-   Ruby On Rails 4.1.6
-   MySQL

1.  Clone to local
2.  Setup environment

    If you use `rvm` then

    ```bash
    echo ruby=2.1.4 >> .versions.conf
    echo ruby-gemset=publify >> .versions.conf
    cd .. && cd publify
    ```
    then

    ```bash
    cp config/database.yml.example config/database.yml
    cp config/mail.yml.example config/mail.yml
    cp .env.example .env
    ```
3.  Edit `.env` file to add your database name, login and password.
4.  Setup Rails

    ```bash
    $ bundle install
    $ rake db:create
    $ rake db:migrate
    $ rake db:seed
    $ rake assets:precompile
    $ rails server
    ```

You can now launch you browser and access to 127.0.0.1:3000.
Default user
```
admin / admin
```
