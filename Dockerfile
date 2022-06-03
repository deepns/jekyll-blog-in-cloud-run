# naming this stage as build
FROM ruby as jekyll-build

# Install bundler gem
RUN gem install bundler

WORKDIR /work

# Copy Gemfile into /work and run bundle install
# to install the required dependencies
COPY Gemfile* /work/
RUN bundle install

# Copy workspace contents into /work
COPY . .

# Set necessary environment variables for the build
ENV JEKYLL_ENV=production
RUN bundle exec jekyll build

# Now that _site is built in /work directory, lets take
# that into the nginx image.
FROM nginx
COPY --from=jekyll-build  /work/_site /usr/share/nginx/html
COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
