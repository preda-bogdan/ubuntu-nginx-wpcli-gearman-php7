FROM ubuntu:16.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
		software-properties-common \
		language-pack-en-base \
		build-essential \
		bash \
		sudo \
		nano \
		cron \
		wget \
		unzip \
		mysql-client \
        openssh-client \
        git \
        curl \
		nginx \
	&& LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php && apt-get update && apt-get install -y --no-install-recommends \
		php7.1-fpm \
		php7.1-common \
		php7.1-mbstring \
		php7.1-xmlrpc \
		php7.1-soap \
		php7.1-gd \
		php7.1-xml \
		php7.1-intl \
		php7.1-mysql \
		php7.1-cli \
		php7.1-mcrypt \
		php7.1-zip \
		php7.1-curl \
		php7.1-dev \
		gearman-job-server \
		libgearman-dev \
		supervisor \
	 && apt-get clean \
     && rm -rf /var/lib/apt/lists/*

RUN curl -o master.zip -fSL https://github.com/wcgallego/pecl-gearman/archive/master.zip

RUN unzip master.zip
WORKDIR /pecl-gearman-master
RUN phpize \
	&& ./configure \
	&& make install \
	&& echo "extension=gearman.so" > /etc/php/7.1/mods-available/gearman.ini \
	&& phpenmod -v ALL -s ALL gearman \
	&& rm /master.zip \
	&& rm -rf /pecl-gearman-master

RUN curl -o /bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

COPY wp.sh /bin/wp

RUN chmod +x /bin/wp-cli.phar /bin/wp

ENV WORDPRESS_VERSION 4.9.6
ENV WORDPRESS_SHA1 40616b40d120c97205e5852c03096115c2fca537

RUN mkdir -p /home/wordpress

RUN set -ex; \
	curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
	echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c -; \
	tar -xzf wordpress.tar.gz -C /home/; \
	rm wordpress.tar.gz; \
	chown -R www-data:www-data /home/

RUN cp -R /home/wordpress/* /var/www/html/

RUN chown -R www-data:www-data /var/www/html/

# hadolint ignore=DL3008
RUN apt-get update && apt-get remove docker docker-engine docker.io && apt-get install -y --no-install-recommends \
		apt-transport-https \
		ca-certificates \
		software-properties-common \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

RUN	curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer --version=1.1.2 \
	&& chmod +x /usr/bin/composer

RUN apt-key fingerprint 0EBFCD88

RUN add-apt-repository \
		"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) \
		stable"

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends docker-ce \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

COPY gearman/gearman.conf /etc/gearmand.conf

COPY supervisor/minions.conf /etc/supervisor/conf.d/minions.conf

RUN update-rc.d gearman-job-server defaults && update-rc.d supervisor defaults

COPY nginx/nginx.conf /etc/nginx/sites-enabled/default

COPY phpfpm/php-fpm.conf  /etc/php/7.1/fpm/pool.d/www.conf

# hadolint ignore=DL3001
RUN service php7.1-fpm start

COPY wordpress/.htaccess /var/www/html/.htaccess

COPY wordpress/index.php /var/www/html/index.php

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat

WORKDIR /var/www/html

EXPOSE 80 443

ENTRYPOINT ["docker-entrypoint.sh"]

