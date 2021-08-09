FROM ruby:3.0.2
RUN apt-get update -qq && apt-get install -y libsqlite3-dev redis-server git

WORKDIR /app
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
RUN bundle install

# Add a script to be executed every time the container starts.
EXPOSE 80

#CMD ["ruby", "geo.rb"]
CMD ["uname -a"]