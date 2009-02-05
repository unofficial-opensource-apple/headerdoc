#! /usr/bin/perl
#
# Class name: Struct
# Synopsis: Holds struct info parsed by headerDoc
#
# Author: Matt Morse (matt@apple.com)
# Last Updated: $Date: 2004/02/19 19:32:59 $
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
package HeaderDoc::Struct;

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc printArray printHash);
use HeaderDoc::HeaderElement;
use HeaderDoc::MinorAPIElement;
use HeaderDoc::APIOwner;

@ISA = qw( HeaderDoc::HeaderElement );

use vars qw($VERSION @ISA);
$VERSION = '1.20';

use strict;


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
    $self->{ISUNION} = 0;
    $self->{FIELDS} = ();
}

sub clone {
    my $self = shift;
    my $clone = undef;
    if (@_) {
	$clone = shift;
    } else {
	$clone = HeaderDoc::Struct->new();
    }

    $self->SUPER::clone($clone);

    # now clone stuff specific to function

    $clone->{ISUNION} = $self->{ISUNION};
    $clone->{FIELDS} = $self->{FIELDS};

    return $clone;
}


sub isUnion {
    my $self = shift;
    if (@_) {
	$self->{ISUNION} = shift;
    }
    return $self->{ISUNION};
}

sub fields {
    my $self = shift;
    if (@_) { 
        @{ $self->{FIELDS} } = @_;
    }
    ($self->{FIELDS}) ? return @{ $self->{FIELDS} } : return ();
}

sub addField {
    my $self = shift;
    if (@_) { 
        push (@{$self->{FIELDS}}, @_);
    }
    return @{ $self->{FIELDS} };
}

sub processStructComment {
    my $self = shift;
    my $fieldArrayRef = shift;
    my @fields = @$fieldArrayRef;
	foreach my $field (@fields) {
		SWITCH: {
            ($field =~ /^\/\*\!/)&& do {last SWITCH;}; # ignore opening /*!
            (($field =~ s/^struct(\s+)/$1/)  || ($field =~ s/^union(\s+)/$1/))&& 
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
            ($field =~ s/^field\s+//) && 
            do {
				$field =~ s/^\s+|\s+$//g;
	            $field =~ /(\w*)\s*(.*)/s;
	            my $fName = $1;
	            my $fDesc = $2;
	            my $fObj = HeaderDoc::MinorAPIElement->new();
	            $fObj->outputformat($self->outputformat);
	            $fObj->name($fName);
		    $fObj->type("field");
	            $fObj->discussion($fDesc);
	            $self->addField($fObj);
				last SWITCH;
			};
	    # my $filename = $HeaderDoc::headerObject->name();
	    my $filename = $self->filename();
	    my $linenum = $self->linenum();
            print "$filename:$linenum:Unknown field in Structu comment: $field\n";
		}
	}
}

sub setStructDeclaration {
    my $self = shift;
    my $dec = shift;
    my $localDebug = 0;
    $self->declaration($dec);
    
    print "============================================================================\n" if ($localDebug);
    print "Raw declaration is: $dec\n" if ($localDebug);

    # my $newdec = $self->structformat($dec, 1);
    
    # print "new dec is:\n$newdec\n" if ($localDebug);
    # $dec = $newdec;

    if (length ($dec)) {$dec = "<pre>\n$dec</pre>\n";};
    
    print "Struct: returning declaration:\n\t|$dec|\n" if ($localDebug);
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
    # my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();

    my $type = "struct";
    if ($self->isUnion()) {
	$type = "union";
    }
    my $uid = $self->apiuid("tag"); # "//$apiUIDPrefix/c/tag/$name";
    # registerUID($uid);
    $contentString .= "<struct id=\"$uid\" type=\"$type\">\n"; # apple_ref marker
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
    my $arrayLength = @fields;
    if ($arrayLength > 0) {
        $contentString .= "<fieldlist>\n";
        foreach my $element (@fields) {
            my $fName = $element->name();
            my $fDesc = $element->discussion();
            $contentString .= "<field><name>$fName</name><description>$fDesc</description></field>\n";
        }
        $contentString .= "</fieldlist>\n";
    }
    $contentString .= "</struct>\n";
    return $contentString;
}

sub printObject {
    my $self = shift;
 
    print "Struct\n";
    $self->SUPER::printObject();
    print "Field Descriptions:\n";
    my $fieldArrayRef = $self->{FIELDS};
    if ($fieldArrayRef) {
	my $arrayLength = @{$fieldArrayRef};
	if ($arrayLength > 0) {
            &printArray(@{$fieldArrayRef});
	}
    }
    print "\n";
}

1;

