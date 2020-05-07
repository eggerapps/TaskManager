LIBSSH2_REPO=https://github.com/libssh2/libssh2.git
LIBSSH2_COMMIT=b3b45813d61c66d0e95b36665ff8d7f0dd662a9d
LIBSSH2_VERSION=${LIBSSH2_COMMIT}
OPENSSL_VERSION=1.1.1g
POSTGRES_VERSION=10.12

PREFIX=$(CURDIR)/install

SDK_ROOT=/Applications/Xcode/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk
PKG_CONFIG_PATH=${SDK_ROOT}/usr/lib/pkgconfig 

# compiler options
MACOSX_DEPLOYMENT_TARGET=10.7
CFLAGS:=$(CFLAGS) -mmacosx-version-min=10.7 -g
CXXFLAGS:=$(CFLAGS) -mmacosx-version-min=10.7 -g

export CFLAGS CXXFLAGS MACOSX_DEPLOYMENT_TARGET

# command shortcuts
CURL=/usr/bin/curl -L10 --silent --show-error --remote-name
TAR=/usr/bin/tar xzf

all: libssh2 openssl postgresql

clean: clean-libssh2 clean-postgresql clean-openssl

#########################
#######  LibSSH2  #######
#########################

libssh2: libssh2.h libssh2.a

libssh2.h: libssh2-${LIBSSH2_VERSION}/configure
	cp libssh2-${LIBSSH2_VERSION}/include/libssh2.h libssh2.h

libssh2.a: libssh2-${LIBSSH2_VERSION}/src/.libs/libssh2.a
	cp libssh2-${LIBSSH2_VERSION}/src/.libs/libssh2.a libssh2.a

libssh2-${LIBSSH2_VERSION}/src/.libs/libssh2.a: libssh2-${LIBSSH2_VERSION}/configure $(PREFIX)/lib/libssl.a
	cd libssh2-${LIBSSH2_VERSION} && ./configure --prefix=${PREFIX} --disable-shared --disable-examples-build
	make -C libssh2-${LIBSSH2_VERSION}

libssh2-${LIBSSH2_VERSION}/configure:
	git clone "${LIBSSH2_REPO}" libssh2-${LIBSSH2_VERSION}
	cd "libssh2-${LIBSSH2_VERSION}" && git checkout $(LIBSSH2_COMMIT)
	cd "libssh2-${LIBSSH2_VERSION}" && ./buildconf
	touch $@
	
clean-libssh2:
	rm -Rf "libssh2-${LIBSSH2_VERSION}"
	rm -f libssh2.a
	
	
#########################
###### PostgreSQL #######
#########################

postgresql: libpq.a postgres_ext.h libpq-fe.h pg_config_ext.h

postgres_ext.h: postgresql-$(POSTGRES_VERSION)/GNUmakefile
	cp postgresql-$(POSTGRES_VERSION)/src/include/postgres_ext.h postgres_ext.h
	
pg_config_ext.h: postgresql-$(POSTGRES_VERSION)/GNUmakefile
	cp postgresql-$(POSTGRES_VERSION)/src/include/pg_config_ext.h pg_config_ext.h
	
libpq-fe.h: postgresql-$(POSTGRES_VERSION)/GNUmakefile
	cp postgresql-$(POSTGRES_VERSION)/src/interfaces/libpq/libpq-fe.h libpq-fe.h

libpq.a: postgresql-$(POSTGRES_VERSION)/GNUmakefile
	make -C postgresql-$(POSTGRES_VERSION)/src/interfaces/libpq all-static-lib
	cp postgresql-$(POSTGRES_VERSION)/src/interfaces/libpq/libpq.a libpq.a
	
postgresql-$(POSTGRES_VERSION)/GNUmakefile: $(PREFIX)/lib/libssl.a postgresql-$(POSTGRES_VERSION)/configure 
	cd "postgresql-$(POSTGRES_VERSION)" && export PATH="$(PREFIX)/bin:$$PATH" && ./configure --prefix=$(PREFIX) --with-includes="$(PREFIX)/include" --with-libraries="$(PREFIX)/lib" --with-openssl --disable-shared

postgresql-$(POSTGRES_VERSION)/configure: postgresql-$(POSTGRES_VERSION).tar.bz2
	$(TAR) "postgresql-$(POSTGRES_VERSION).tar.bz2"
	patch -b postgresql-$(POSTGRES_VERSION)/src/interfaces/libpq/fe-secure-openssl.c patches/fe-secure-openssl.c.patch
	patch -b postgresql-$(POSTGRES_VERSION)/src/interfaces/libpq/fe-connect.c patches/fe-connect.c.patch
	touch $@

postgresql-$(POSTGRES_VERSION).tar.bz2:	
	$(CURL) "https://ftp.postgresql.org/pub/source/v$(POSTGRES_VERSION)/postgresql-$(POSTGRES_VERSION).tar.bz2"
	
clean-postgresql:
	rm -Rf postgresql-$(POSTGRES_VERSION)


#########################
####### OpenSSL #########
#########################

openssl: libssl.a libcrypto.a

libssl.a: $(PREFIX)/lib/libssl.a
	cp $(PREFIX)/lib/libssl.a libssl.a
	
libcrypto.a: $(PREFIX)/lib/libssl.a
	cp $(PREFIX)/lib/libcrypto.a libcrypto.a

$(PREFIX)/lib/libssl.a: openssl-$(OPENSSL_VERSION)/Makefile
	make -C openssl-$(OPENSSL_VERSION)
	make -C openssl-$(OPENSSL_VERSION) install_sw

openssl-$(OPENSSL_VERSION)/Makefile: openssl-$(OPENSSL_VERSION)/Configure
	cd openssl-$(OPENSSL_VERSION) && ./Configure --prefix=$(PREFIX) darwin64-x86_64-cc no-asm

openssl-$(OPENSSL_VERSION)/Configure: openssl-$(OPENSSL_VERSION).tar.gz
	$(TAR) openssl-$(OPENSSL_VERSION).tar.gz
	touch $@

openssl-$(OPENSSL_VERSION).tar.gz:
	$(CURL) "https://www.openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz"
	
clean-openssl:
	rm -Rf "openssl-$(OPENSSL_VERSION)"
