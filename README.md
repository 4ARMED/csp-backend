[![Docker Repository on Quay](https://quay.io/repository/4armed/csp-backend/status "Docker Repository on Quay")](https://quay.io/repository/4armed/csp-backend)
[![Known Vulnerabilities](https://snyk.io/test/github/4ARMED/csp-backend/badge.svg?targetFile=src%2FGemfile.lock)](https://snyk.io/test/github/4ARMED/csp-backend?targetFile=src%2FGemfile.lock)

# 4ARMED's CSP Generator

This is the backend API for 4ARMED's Content Security Policy Generator. It provides a CSP report-uri handler along with the ability to generate a CSP based on reported violations.

Its sole interface is a JSON API. The easiest way is to run it using Docker using our [docker-compose.yml](https://github.com/4armed/csp-generator) and the easiest way to interact with it is via our [Google Chrome Extension](https://github.com/4armed/csp-generator-extension).

## Prerequisites

If you are not installing it in Docker then you're probably either crazy or you're looking to hack this thing into shape. You're going to need a couple of things.

1. Ruby

   This thing is written in Ruby. I used 2.3 but it should be good for any 2.0+ release of MRI.

   I recommended using RVM or rbenv to get your Ruby installed.

2. Bundler

   CSP Generator uses Bundler to manage the required gems. Install it:

   ```shell
   $ gem install bundler
   ```

3. MongoDB

   The backend data store is MongoDB so you will need an instance of this running. If you're on macOS you can use HomeBrew (if you've installed it) and do:

   ```shell
   $ brew install mongo
   ```

   Once installed, make sure it's running:

   ```shell
   $ mongod --config /usr/local/etc/mongod.conf &
   ```

## Installation

1. Clone this repo

   ```shell
   $ git clone https://github.com/4armed/csp-backend.git
   ```

2. Install Ruby dependencies

   ```shell
   $ cd csp-backend
   $ bundle install
   ```

3. Start the app

   ```shell
   $ ruby app.rb
   == Sinatra (v1.4.7) has taken the stage on 4567 for development with backup from Thin
   Thin web server (v1.7.0 codename Dunder Mifflin)
   Maximum connections set to 1024
   Listening on localhost:4567, CTRL+C to stop
   ```

# Usage

The app is now up and running on localhost:4567. Using this configuration you can generate and test CSPs for any non-HTTPS website by setting the remote site's report-uri to http://localhost:4567/report.

The best approach is to set a very restrictive (i.e. permit nothing) CSP using the Content-Security-Policy-Report-Only HTTP response header. This will not interrupt the functioning of the site but will generate all the report violations we need.

An example policy is:

```
default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; report-uri http://localhost:4567/report;
```

Browse the target site and it will record violations via the app into Mongo.

To create a policy just go to http://localhost:4567/policy/<url of site>. Let's say you were building a CSP config for w<span>ww.bbc.co</span>.uk then you would go to http://localhost:4567/policy/<span>ww</span>w.bbc.co.uk. 

Non-standard ports are supported, just append the colon and port number at the end, making sure the colon is URL encoded as %3A.

http://localhost:4567/policy/w<span>ww.bb</span>c.co.uk%3A81

## How to set the CSP header on the remote site.

Of course, how you add HTTP response headers will depend on the website in question. Apache and Nginx have set directives for headers. IIS headers can be configured in the IIS Management Console.

But there is another way!

Using our open source [Google Chrome Extension](https://github.com/4armed/csp-generator-extension) you can insert CSP headers for any website just in your Chrome browser. The best thing is that it provides a neat way to interact with the API so you can then generate the policy and try it out right in your browser.

Head on over to that Github page for more info and a demo video.

## Test page

There's a test page included that incorporates a bunch of script, images and styles so you can play around with CSP. This test page is designed to be used with the Google Chrome Extension as otherwise you're back to playing around with HTTP response headers in Rack or Sinatra.

## Changes

Please feel free to fork this repo and submit improvements. There will be lots!!

Send pull requests from a dedicated branch for your proposed changes.
