FROM php:8.1-apache-bullseye AS bz2-builder

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN apt-get update && apt-get install -y --no-install-recommends apt-utils

RUN chmod +x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions bz2
#
# Use a temporary image to compile and test the libraries
#
FROM nextcloud:apache as builder

# Build and install dlib on builder

RUN apt-get update ; \
    apt-get install -y build-essential wget cmake libx11-dev libopenblas-dev git liblapack-dev

RUN git clone https://github.com/davisking/dlib.git \
    && cd dlib/dlib \
    && mkdir build \
    && cd build \
    && cmake -DBUILD_SHARED_LIBS=ON .. \
    && make \
    && make install
# ARG DLIB_BRANCH=v19.19
# RUN wget -c -q https://github.com/davisking/dlib/archive/$DLIB_BRANCH.tar.gz \
#     && tar xf $DLIB_BRANCH.tar.gz \
#     && mv dlib-* dlib \
#     && cd dlib/dlib \
#     && mkdir build \
#     && cd build \
#     && cmake -DBUILD_SHARED_LIBS=ON --config Release .. \
#     && make \
#     && make install

# Build and install PDLib on builder

RUN git clone https://github.com/goodspb/pdlib.git \
    && cd pdlib \
    && phpize \
    && cat configure | sed 's/std=c++11/std=c++14/g' > configure_new \
    && chmod +x configure_new \
    && ./configure_new --enable-debug \
    && make \
    && make install
# ARG PDLIB_BRANCH=master
# RUN apt-get install unzip
# RUN wget -c -q https://github.com/matiasdelellis/pdlib/archive/$PDLIB_BRANCH.zip \
#     && unzip $PDLIB_BRANCH \
#     && mv pdlib-* pdlib \
#     && cd pdlib \
#     && phpize \
#     && ./configure \
#     && make \
#     && make install

# Enable PDlib on builder

# If necesary take the php settings folder uncommenting the next line
# RUN php -i | grep "Scan this dir for additional .ini files"
RUN echo "extension=pdlib.so" > /usr/local/etc/php/conf.d/pdlib.ini

# Test PDlib instalation on builer

# RUN apt-get install -y git
# RUN git clone https://github.com/matiasdelellis/pdlib-min-test-suite.git \
#     && cd pdlib-min-test-suite \
#     && make

#
# If pass the tests, we are able to create the final image.
#

FROM nextcloud:apache

# Install dependencies to image

RUN apt-get update ; \
    apt-get install -y libopenblas-base vim

# Install dlib and PDlib to image

COPY --from=builder /usr/local/lib/libdlib.so* /usr/local/lib/

# If is necesary take the php extention folder uncommenting the next line
# RUN php -i | grep extension_dir
COPY --from=builder /usr/local/lib/php/extensions/no-debug-non-zts-20210902/pdlib.so /usr/local/lib/php/extensions/no-debug-non-zts-20210902/
COPY --from=bz2-builder /usr/local/lib/php/extensions/no-debug-non-zts-20210902/bz2.so /usr/local/lib/php/extensions/no-debug-non-zts-20210902/

# Enable PDlib on final image

RUN echo "extension=pdlib.so" > /usr/local/etc/php/conf.d/pdlib.ini
RUN echo "extension=bz2.so" > /usr/local/etc/php/conf.d/bz2.ini

# Increse memory limits

RUN echo memory_limit=2048M > /usr/local/etc/php/conf.d/memory-limit.ini
RUN rm /usr/local/etc/php/conf.d/nextcloud.ini
RUN echo memory_limit=2048M > /usr/local/etc/php/conf.d/nextcloud.ini

# Pdlib is already installed, now without all build dependencies.
# You could test again if everything is correct, uncommenting the next lines
#
# RUN apt-get install -y git wget
# RUN git clone https://github.com/matiasdelellis/pdlib-min-test-suite.git \
#    && cd pdlib-min-test-suite \
#    && make

#
# At this point you meet all the dependencies to install the application
# If is available you can skip this step and install the application from the application store
#
# ARG FR_BRANCH=master
RUN apt-get install -y wget unzip nodejs npm
RUN git clone https://github.com/matiasdelellis/facerecognition.git \
  && mv facerecognition /usr/src/nextcloud/custom_apps/ \
  && cd /usr/src/nextcloud/custom_apps/facerecognition \
  && mv webpack.common.js webpack.common.js.backup \
  && sed '44d' webpack.common.js.backup > webpack.common.js \
  && make
