#! /usr/bin/perl
#
# Class name: PDefined
# Synopsis: Holds headerDoc comments of the @define type, which
#           are used to comment symbolic constants declared with #define
#
# Author: Matt Morse (matt@apple.com)
# Last Updated: $Date: 2004/02/09 18:37:23 $
# 
# Copyright (c) 1999-2004 Apple Computer, Inc.  All rights reserved.
#
# @APPLE_LICENSE_HEADER_START@
#
# This file contains Original Code and/or Modifications of Original Code
# as defined in and that are subject to the Apple Public Source License
# Version 2.0 (the 'License'). You may not use this file except in
# compliance with the License. Please obtain a copy of the License at
# http://www.opensource.apple.com/apsl/ and read it before using this
# file.
# 
# The Original Code and all software distributed under the License are
# distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
# INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
# Please see the License for the specific language governing rights and
# limitations under the License.
#
# @APPLE_LICENSE_HEADER_END@
#
######################################################################
package HeaderDoc::PDefine;
use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc convertCharsForFileMaker printArray printHash);
use HeaderDoc::HeaderElement;

@ISA = qw( HeaderDoc::HeaderElement );
use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.20';

sub new {
    my($param) = shift;
    my($class) = ref($param) || $param;
    my $self = {};

    bless($self, $class);
    $self->_initialize();
    return($self);
}

sub _initialize {    
    my($self) = shift;

    $self->SUPER::_initialize();
    $self->{ISBLOCK} = 0;
    $self->{RESULT} = undef;
}

sub clone {
    my $self = shift;
    my $clone = undef;
    if (@_) {
	$clone = shift;
    } else {
	$clone = HeaderDoc::PDefine->new();
    }

    $self->SUPER::clone($clone);

    # now clone stuff specific to function

    $clone->{ISBLOCK} = $self->{ISBLOCK};
    $clone->{RESULT} = $self->{RESULT};

    return $clone;
}


sub processPDefineComment {
    my $localDebug = 0;
    my($self) = shift;
    my $fieldArrayRef = shift;
    my @fields = @$fieldArrayRef;
	foreach my $field (@fields) {
        chomp($field);
		SWITCH: {
            ($field =~ /^\/\*\!/)&& do {last SWITCH;}; # ignore opening /*!
            ($field =~ s/^define(d)?(\s+)// || $field =~ s/^function\s+//) && do {
		    if (length($2)) { $field = "$2$field"; }
		    else { $field = "$1$field"; }
		    my ($defname, $defabstract_or_disc) = getAPINameAndDisc($field);
		    if ($self->isBlock()) {
			# print "ISBLOCK\n";
			# my ($defname, $defabstract_or_disc) = getAPINameAndDisc($field);
			# In this case, we get a name and abstract.
			print "Added alternate name $defname\n" if ($localDebug);
			$self->attributelist("Included Defines", $field);
		    } else {
			# print "NOT BLOCK\n";
			$self->name($defname);
			if (length($defabstract_or_disc)) {
				$self->discussion($defabstract_or_disc);
			}
		    }
		    last SWITCH;
		};
            ($field =~ s/^define(d)?block(\s+)//) && do {
		    if (length($2)) { $field = "$2$field"; }
		    else { $field = "$1$field"; }
		    my ($defname, $defdisc) = getAPINameAndDisc($field);
		    $self->isBlock(1);
		    $self->name($defname);
		    $self->discussion($defdisc);
		    last SWITCH;
		};
            ($field =~ s/^abstract\s+//) && do {$self->abstract($field); last SWITCH;};
            ($field =~ s/^discussion\s+//) && do {$self->discussion($field); last SWITCH;};
            ($field =~ s/^availability\s+//) && do {$self->availability($field); last SWITCH;};
            ($field =~ s/^since\s+//) && do {$self->availability($field); last SWITCH;};
            ($field =~ s/^author\s+//) && do {$self->attribute("Author", $field, 0); last SWITCH;};
	    ($field =~ s/^version\s+//) && do {$self->attribute("Version", $field, 0); last SWITCH;};
            ($field =~ s/^deprecated\s+//) && do {$self->attribute("Deprecated", $field, 0); last SWITCH;};
            ($field =~ s/^updated\s+//) && do {$self->updated($field); last SWITCH;};
            ($field =~ s/^param\s+//) && do {
                    $field =~ s/^\s+|\s+$//g; # trim leading and trailing whitespace
                    # $field =~ /(\w*)\s*(.*)/s;
                    $field =~ /(\S*)\s*(.*)/s;
                    my $pName = $1;
                    my $pDesc = $2;
                    my $param = HeaderDoc::MinorAPIElement->new();
                    $param->outputformat($self->outputformat);
                    $param->name($pName);                    $param->discussion($pDesc);
                    $self->addTaggedParameter($param);
                                last SWITCH;
		};
	    ($field =~ /^see(also|)\s+/) &&
		do {
		    $self->see($field);
		    last SWITCH;
		};
	    ($field =~ s/^return\s+//) && do {$self->result($field); last SWITCH;};
	    ($field =~ s/^result\s+//) && do {$self->result($field); last SWITCH;};
	    # my $filename = $HeaderDoc::headerObject->name();
	    my $filename = $self->filename();
	    my $linenum = $self->linenum();
            print "$filename:$linenum:Unknown field in #define comment: $field\n";
		}
	}
}

sub setPDefineDeclaration {
    my($self) = shift;
    my ($dec) = @_;
    my $localDebug = 0;
    $self->declaration($dec);
    my $filename = $self->filename();
    my $line = 0;

    # if ($dec =~ /#define.*#define/s && !($self->isBlock)) {
	# warn("$filename:$line:WARNING: Multiple #defines in \@define.  Use \@defineblock instead.\n");
    # }
    
    print "============================================================================\n" if ($localDebug);
    print "Raw #define declaration is: $dec\n" if ($localDebug);
    
    $dec =~ s/^\s+//;
    $dec =~ s/\t/ /g;
    $dec =~ s/</&lt;/g;
    $dec =~ s/>/&gt;/g;

    if (length ($dec)) {$dec = "<pre>\n$dec</pre>\n";};
    print "#define: returning declaration:\n\t|$dec|\n" if ($localDebug);
    print "============================================================================\n" if ($localDebug);
    $self->declarationInHTML($dec);
    return $dec;
}

sub isBlock {
    my $self = shift;

    if (@_) {
	$self->{ISBLOCK} = shift;
    }

    return $self->{ISBLOCK};
}


sub XMLdocumentationBlock {
    my $self = shift;
    my $name = $self->name();
    my $desc = $self->discussion();
    my $declaration = $self->declarationInHTML();
    my $abstract = $self->abstract();
    my $availability = $self->availability();
    my $updated = $self->updated();
    my $group = $self->group();
    my $result = $self->result();
    my $contentString;
 
    $contentString .= "<define id=\"$name\">\n";
    if (length($abstract)) {
        $contentString .= "<abstract>$abstract</abstract>\n";
    }
    if (length($availability)) {
        $contentString .= "<availability>$availability</availability>\n";
    }
    if (length($updated)) {
        $contentString .= "<updated>$updated</updated>\n";
    }
    if (length($group)) {
	$contentString .= "<group>$group</group>\n";
    }
    $contentString .= "<declaration>$declaration</declaration>\n";
    $contentString .= "<description>$desc</description>\n";
    if (length($result)) {
        $contentString .= "<result>$result</result>\n";
    }
    $contentString .= "</define>\n";
    return $contentString;
}


sub result {
    my $self = shift;
    
    if (@_) {
        $self->{RESULT} = shift;
    }
    return $self->{RESULT};
}


sub printObject {
    my $self = shift;
 
    print "#Define\n";
    $self->SUPER::printObject();
    print "Result: $self->{RESULT}\n";
    print "\n";
}

1;

