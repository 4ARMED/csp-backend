FROM ruby:2.6-alpine
LABEL maintainer="Marc Wickenden <marc@4armed.com>"

# Create the group and user to be used in this container
RUN addgroup -S app && adduser -S app -G app

# App directory and permissions
WORKDIR /app

# Install gems
RUN gem install bundler 
ADD src/Gemfile .
ADD src/Gemfile.lock .
ADD src/config.ru .

RUN apk --update add --virtual build_deps \
    build-base && \
    bundle install --deployment --without development test && \
    apk del build_deps

RUN apk --update add libstdc++

ADD src/app.rb .
ADD src/public/ public/

USER app
CMD ["bundle", "exec", "rackup", "-p", "4567"]
