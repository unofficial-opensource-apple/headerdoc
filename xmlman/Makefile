
CFLAGS= -I/usr/include/libxml2
# -g
LDFLAGS= -lxml2

all: xml2man hdxml2manxml
	strip xml2man
	strip hdxml2manxml

clean:
	rm -f xml2man hdxml2manxml

xml2man: xml2man.c
hdxml2manxml: hdxml2manxml.c

