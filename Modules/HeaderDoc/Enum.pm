#! /usr/bin/perl -w
#
# Class name: Enum
# Synopsis: Holds struct info parsed by headerDoc
#
# Author: Matt Morse (matt@apple.com)
# Last Updated: $Date: 2004/02/05 07:01:48 $
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
package HeaderDoc::Enum;

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc printArray printHash);
use HeaderDoc::HeaderElement;
use HeaderDoc::MinorAPIElement;
use HeaderDoc::APIOwner;

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
}

sub clone {
    my $self = shift;
    my $clone = undef;
    if (@_) {
	$clone = shift;
    } else {
	$clone = HeaderDoc::Enum->new();
    }

    $self->SUPER::clone($clone);

    # now clone stuff specific to enum

    return $clone;
}


sub processEnumComment {
    my $self = shift;
    my $fieldArrayRef = shift;
    my @fields = @$fieldArrayRef;
	foreach my $field (@fields) {
		SWITCH: {
            ($field =~ /^\/\*\!/)&& do {last SWITCH;}; # ignore opening /*!
            ($field =~ s/^enum(\s+)/$1/) && 
            do {
                my ($name, $disc);
                ($name, $disc) = &getAPINameAndDisc($field); 
                $self->name($name);
                if (length($disc)) {$self->discussion($disc);};
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
	    ($field =~ /^see(also|)\s+/) &&
		do {
		    $self->see($field);
		    last SWITCH;
		};
            ($field =~ s/^constant\s+//) && 
            do {
				$field =~ s/^\s+|\s+$//g;
	            $field =~ /(\w*)\s*(.*)/s;
	            my $cName = $1;
	            my $cDesc = $2;
	            my $cObj = HeaderDoc::MinorAPIElement->new();
	            $cObj->outputformat($self->outputformat);
	            $cObj->name($cName);
	            $cObj->discussion($cDesc);
                $self->addConstant($cObj); 
		my $name = $self->name();
		if ($name eq "") {
		    $name = "$cName";
		    $self->name($name);
		}
                last SWITCH;
            };
	    # my $filename = $HeaderDoc::headerObject->filename();
	    my $filename = $self->filename();
	    my $linenum = $self->linenum();
            print "$filename:$linenum:Unknown field in Enum comment: $field\n";
		}
	}
}

sub getEnumDeclaration {
    my $self = shift;
    my $dec = shift;
    my $localDebug = 0;
    
    print "============================================================================\n" if ($localDebug);
    print "Raw declaration is: $dec\n" if ($localDebug);
    
    $dec =~ s/\t/  /g;
    $dec =~ s/</&lt;/g;
    $dec =~ s/>/&gt;/g;
    if (length ($dec)) {$dec = "<pre>\n$dec</pre>\n";};
    
    print "Enum: returning declaration:\n\t|$dec|\n" if ($localDebug);
    print "============================================================================\n" if ($localDebug);
    return $dec;
}


sub XMLdocumentationBlock {
    my $self = shift;
    my $name = $self->name();
    my $abstract = $self->abstract();
    my $availability = $self->availability();
    my $updated = $self->updated();
    my $desc = $self->discussion();
    my $declaration = $self->declarationInHTML();
    my @constants = $self->constants();
    my $group = $self->group();
    my $contentString;
    # my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();
    
    my $uid = $self->apiuid("tag"); # "//$apiUIDPrefix/c/tag/$name";
    # registerUID($uid);
    $contentString .= "<enum id=\"$uid\">\n"; # apple_ref marker
    $contentString .= "<name>$name</name>\n";
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
    my $arrayLength = @constants;
    if ($arrayLength > 0) {
        $contentString .= "<constantlist>\n";
        foreach my $element (@constants) {
            my $cName = $element->name();
            my $cDesc = $element->discussion();
            # my $uid = "//$apiUIDPrefix/c/econst/$cName";
	    # registerUID($uid);
	    my $uid = $element->apiuid("econst");
            $contentString .= "<constant id=\"$uid\">\n";
	    $contentString .= "<name>$cName</name>\n";
	    $contentString .= "<description>$cDesc</description>\n";
	    $contentString .= "</constant>\n";
        }
        $contentString .= "</constantlist>\n";
    }
    $contentString .= "</enum>\n";
    return $contentString;
}

sub printObject {
    my $self = shift;
 
    print "Enum\n";
    $self->SUPER::printObject();
    print "Constants:\n";
}

1;

