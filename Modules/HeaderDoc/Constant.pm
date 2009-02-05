#! /usr/bin/perl -w
#
# Class name: Constant
# Synopsis: Holds constant info parsed by headerDoc
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
package HeaderDoc::Constant;

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc convertCharsForFileMaker printArray printHash);
use HeaderDoc::HeaderElement;
use HeaderDoc::APIOwner;

@ISA = qw( HeaderDoc::HeaderElement );

use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.20';

sub processConstantComment {
    my($self) = shift;
    my $fieldArrayRef = shift;
    my @fields = @$fieldArrayRef;
    my $localDebug = 0;

	foreach my $field (@fields) {
    	print "Constant field is |$field|\n" if ($localDebug);
		SWITCH: {
            ($field =~ /^\/\*\!/)&& do {last SWITCH;}; # ignore opening /*!
            ($field =~ s/^const(ant)?(\s+)//) && 
            do {
		if (length($2)) { $field = "$2$field"; }
		else { $field = "$1$field"; }
                my ($name, $disc);
                ($name, $disc) = &getAPINameAndDisc($field); 
                $self->name($name);
                if (length($disc)) {$self->discussion($disc);};
                last SWITCH;
            };
	    ($field =~ s/^serial\s+//i) && do {$self->attribute("Serial Field Info", $field, 1); last SWITCH;};
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
	    # my $filename = $HeaderDoc::headerObject->filename();
	    my $filename = $self->filename();
	    my $linenum = $self->linenum();
            print "$filename:$linenum:Unknown field in constant comment: $field\n";
		}
	}
}

sub setConstantDeclaration {
    my($self) = shift;
    my ($dec) = @_;
    my $localDebug = 0;
    
    print "============================================================================\n" if ($localDebug);
    print "Raw constant declaration is: $dec\n" if ($localDebug);
    $self->declaration($dec);
    
    $dec =~ s/^extern\s+//;
    $dec =~ s/\t/ /g;
    $dec =~ s/</&lt;/g;
    $dec =~ s/>/&gt;/g;
    if (length ($dec)) {$dec = "<pre>\n$dec</pre>\n";};
    print "Constant: returning declaration:\n\t|$dec|\n" if ($localDebug);
    print "============================================================================\n" if ($localDebug);
    $self->declarationInHTML($dec);
    return $dec;
}


sub XMLdocumentationBlock {
    my $self = shift;
    my $contentString;
    my $name = $self->name();
    my $abstract = $self->abstract();
    my $availability = $self->availability();
    my $updated = $self->updated();
    my $desc = $self->discussion();
    my $declaration = $self->declarationInHTML();
    my $group = $self->group();
    my $value = $self->value();
    # my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();
    
    my $uid = $self->apiuid("data"); # "//$apiUIDPrefix/c/data/$name";
    # registerUID($uid);

    $contentString .= "<const id=\"$uid\">\n"; # apple_ref marker
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
    if (length($value)) {
	$contentString .= "<value>$value</value>\n";
    }
    $contentString .= "<declaration>$declaration</declaration>\n";
    $contentString .= "<description>$desc</description>\n";
    $contentString .= "</const>\n";

    my $value_fixed_contentString = $self->fixup_values($contentString);
    return $value_fixed_contentString;
}

sub printObject {
    my $self = shift;
 
    print "Constant\n";
    $self->SUPER::printObject();
    print "\n";
}

1;

