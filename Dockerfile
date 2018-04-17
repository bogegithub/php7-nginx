FROM alpine:3.7

ENV VERSION 0.0.1

MAINTAINER Ruolinn "guangxiao.wang@gmail.com"

ENV TIMEZONE Asia/Shanghai

#RUN echo https://mirror.tuna.tsinghua.edu.cn/alpine/edge/main | tee -a /etc/apk/repositories \
#    && echo @testing https://mirror.tuna.tsinghua.edu.cn/alpine/edge/testing | tee -a /etc/apk/repositories \
#    && echo @community https://mirror.tuna.tsinghua.edu.cn/alpine/edge/community | tee -a /etc/apk/repositories

RUN echo https://mirror.tuna.tsinghua.edu.cn/alpine/v3.7/main | tee -a /etc/apk/repositories \
    && echo @community https://mirror.tuna.tsinghua.edu.cn/alpine/v3.7/community | tee -a /etc/apk/repositories


RUN apk update

RUN apk add --update tzdata
RUN cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo "${TIMEZONE}" > /etc/timezone

RUN apk --update add \
    build-base \
    make \
    git \
    zlib-dev \
    zsh \
    nginx \
    openssh \
    supervisor \
    curl \
    curl-dev

RUN apk --update add \
    php7 \
    php7-dev \
    php7-intl \
    php7-posix \
    php7-pcntl \
    php7-mcrypt \
    php7-mbstring \
		php7-openssl \
		php7-json \
    php7-dom \
		php7-pdo \
		php7-zip \
		php7-mysqli \
    php7-redis \
		php7-bcmath \
		php7-gd \
		php7-pdo_mysql \
		php7-gettext \
		php7-bz2 \
    php7-tokenizer \
		php7-iconv \
		php7-curl \
		php7-ctype \
		php7-fpm \
    php7-pear \
    php7-phar \
    php7-fileinfo \
    php7-xmlwriter \
    php7-simplexml \
    php7-zlib 


# Build & install ext/tideways & Tideways.php (props to till)
RUN cd /tmp && \
    curl -L "https://github.com/tideways/php-xhprof-extension/archive/master.zip" \
   	--output "/tmp/master.zip" && \
	  cd /tmp && unzip "master.zip" && \
	  cd "php-xhprof-extension-master" && \
    phpize && \
	  ./configure && \
	  make && make install 

#RUN apk add libssl1.0

#RUN apk add librdkafka-dev && \
#    pecl install rdkafka && \
#    echo extension=rdkafka.so > /etc/php7/conf.d/rdkafka.ini && \
#    pecl clear-cache

RUN pecl install msgpack && \
    echo extension=msgpack.so > /etc/php7/conf.d/msgpack.ini && \
    pecl clear-cache

RUN apk add --virtual .yar-deps curl-dev && \
    pecl install yar && \
    echo extension=yar.so > /etc/php7/conf.d/yar.ini && \
    echo yar.packager=msgpack >> /etc/php7/conf.d/yar.ini && \
    pecl clear-cache && \
    apk del .yar-deps

#RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
COPY config/composer.phar /usr/local/bin/composer

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add application
RUN mkdir -p /workspace
WORKDIR /workspace
VOLUME ["workspace"]

# User config
ENV UID="1000" \
    UNAME="developer" \
    GID="1000" \
    GNAME="developer" \
    SHELL="/bin/zsh" \
    UHOME=/home/developer

# User
RUN apk add sudo \
# Create HOME dir
    && mkdir -p "${UHOME}" \
    && chown "${UID}":"${GID}" "${UHOME}" \
# Create user
    && echo "${UNAME}:x:${UID}:${GID}:${UNAME},,,:${UHOME}:${SHELL}" \
    >> /etc/passwd \
    && echo "${UNAME}::17032:0:99999:7:::" \
    >> /etc/shadow \
# No password sudo
    && echo "${UNAME} ALL=(ALL) NOPASSWD: ALL" \
    > "/etc/sudoers.d/${UNAME}" \
    && chmod 0440 "/etc/sudoers.d/${UNAME}" \
# Create group
    && echo "${GNAME}:x:${GID}:${UNAME}" \
    >> /etc/group

RUN cd $UHOME \
    && git clone --depth 1 git://github.com/robbyrussell/oh-my-zsh.git .oh-my-zsh \
    && cp $UHOME/.oh-my-zsh/templates/zshrc.zsh-template $UHOME/.zshrc

USER $UNAME

RUN sudo mkdir /var/log/supervisord

EXPOSE 80 443

CMD ["sudo", "/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
#ENTRYPOINT ["/bin/zsh"]
