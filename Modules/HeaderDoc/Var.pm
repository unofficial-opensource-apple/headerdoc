#! /usr/bin/perl
#
# Class name: Var
# Synopsis: Holds class and instance data members parsed by headerDoc
#
# Author: Matt Morse (matt@apple.com)
# Last Updated: $Date: 2004/02/05 07:01:49 $
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
package HeaderDoc::Var;

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc printArray printHash);
use HeaderDoc::HeaderElement;
use HeaderDoc::Struct;

# making it a subclass of Struct, so that it has the "fields" ivar.
@ISA = qw( HeaderDoc::Struct );
use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.20';

sub processVarComment {
    my($self) = shift;
    my $fieldArrayRef = shift;
    my @fields = @$fieldArrayRef;
	foreach my $field (@fields) {
		SWITCH: {
            ($field =~ /^\/\*\!/)&& do {last SWITCH;}; # ignore opening /*!
            ($field =~ s/^var(\s+)/$1/) && 
            do {
                my ($name, $disc);
                ($name, $disc) = &getAPINameAndDisc($field); 
                $self->name($name);
                if (length($disc)) {$self->discussion($disc);};
                last SWITCH;
            };
	    ($field =~ s/^serial\s+//i) && do {$self->attribute("Serial Field Info", $field, 1); last SWITCH;};
	    ($field =~ s/^serialfield\s+//i) && do {
		    if (!($field =~ s/(\S+)\s+(\S+)\s+//s)) {
			warn "serialfield format wrong.\n";
		    } else {
			my $name = $1;
			my $type = $2;
			my $description = "(no description)";
			my $att = "$name Type: $type";
			$field =~ s/^(<BR>|\s)*//sgi;
			if (length($field)) {
				$att .= "<br>\nDescription: $field";
			}
			$self->attributelist("Serial Fields", $att,  1);
		    }
		    last SWITCH;
		};
            ($field =~ s/^abstract\s+//) && do {$self->abstract($field); last SWITCH;};
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
            ($field =~ s/^discussion\s+//) && do {$self->discussion($field); last SWITCH;};
	    # my $filename = $HeaderDoc::headerObject->name();
	    my $filename = $self->filename();
	    my $linenum = $self->linenum();
            print "$filename:$linenum:Unknown field in Var comment: $field\n";
		}
	}
}


sub setVarDeclaration {
    my($self) = shift;
    my ($dec) = @_;
    my $localDebug = 0;

    $self->declaration($dec);
    
    print "============================================================================\n" if ($localDebug);
    print "Raw var declaration is: $dec\n" if ($localDebug);
    
    $dec =~ s/^extern\s+//;
    $dec =~ s/\t/ /g;
    $dec =~ s/^\s*//g;
    $dec =~ s/</&lt;/g;
    $dec =~ s/>/&gt;/g;
    if (length ($dec)) {$dec = "<pre>\n$dec</pre>\n";};
    print "Var: returning declaration:\n\t|$dec|\n" if ($localDebug);
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
    my @fields = $self->fields();
    my $fieldHeading = "Field Descriptions";
    
    if ($self->can('isFunctionPointer')) {
        if ($self->isFunctionPointer()) {
            $fieldHeading = "Parameter Descriptions";
        }
    }
    
    $contentString .= "<variable id=\"$name\">\n";
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
    my $arrayLength = @fields;
    if ($arrayLength > 0) {
        $contentString .= "<heading>$fieldHeading</heading>\n";
        $contentString .= "<fieldlist>\n";
        foreach my $element (@fields) {
            my $fName;
            my $fDesc;
            $element =~ s/^\s+|\s+$//g;
            $element =~ /(\w*)\s*(.*)/;
            $fName = $1;
            $fDesc = $2;
            $contentString .= "<field><name>$fName</name><description>$fDesc</description></field>\n";
        }
        $contentString .= "</fieldlist\n";
    }
    $contentString .= "</variable>\n";
    return $contentString;
}


sub printObject {
    my $self = shift;
 
    print "Var\n";
    $self->SUPER::printObject();
    print "\n";
}

1;

