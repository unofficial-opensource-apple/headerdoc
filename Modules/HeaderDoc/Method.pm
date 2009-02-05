#! /usr/bin/perl
#
# Class name: Method
# Synopsis: Holds Objective C method info parsed by headerDoc (not used for C++)
#
# Author: SKoT McDonald  <skot@tomandandy.com> Aug 2001
# Based on Function.pm, and modified, by Matt Morse <matt@apple.com>
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
package HeaderDoc::Method;

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc printArray printHash);
use HeaderDoc::HeaderElement;
use HeaderDoc::MinorAPIElement;
use HeaderDoc::APIOwner;

use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.00';

# Inheritance
@ISA = qw( HeaderDoc::HeaderElement );

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
    $self->{RESULT} = undef;
    $self->{CONFLICT} = 0;
    $self->{OWNER} = undef;
    $self->{ISINSTANCEMETHOD} = "UNKNOWN";
}

sub clone {
    my $self = shift;
    my $clone = undef;
    if (@_) {
	$clone = shift;
    } else {
	$clone = HeaderDoc::Method->new();
    }

    $self->SUPER::clone($clone);

    # now clone stuff specific to function

    $clone->{RESULT} = $self->{RESULT};
    $clone->{CONFLICT} = $self->{CONFLICT};
    $clone->{OWNER} = $self->{OWNER};
    $clone->{ISINSTANCEMETHOD} = $self->{ISINSTANCEMETHOD};

    return $clone;
}


sub setIsInstanceMethod {
    my $self = shift;
    
    if (@_) {
        $self->{ISINSTANCEMETHOD} = shift;
    }
    return $self->{ISINSTANCEMETHOD};
}

sub isInstanceMethod {
    my $self = shift;
    return $self->{ISINSTANCEMETHOD};
}

# Made redundant by apiOwner in HeaderElement
# sub owner {  # class or protocol that this method belongs to
    # my $self = shift;
# 
    # if (@_) {
        # my $name = shift;
        # $self->{OWNER} = $name;
    # } else {
    	# my $n = $self->{OWNER};
		# return $n;
	# }
# }

sub result {
    my $self = shift;
    
    if (@_) {
        $self->{RESULT} = shift;
    }
    return $self->{RESULT};
}


sub conflict {
    my $self = shift;
    my $localDebug = 0;
    if (@_) { 
        $self->{CONFLICT} = @_;
    }
    print "conflict $self->{CONFLICT}\n" if ($localDebug);
    return $self->{CONFLICT};
}


sub processMethodComment {
    my $self = shift;
    my $fieldArrayRef = shift;
    my @fields = @$fieldArrayRef;
	foreach my $field (@fields) {
		SWITCH: {
			($field =~ /^\/\*\!/)&& do {last SWITCH;}; # ignore opening /*!
			($field =~ s/^method(\s+)/$1/) && 
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
			($field =~ s/^param\s+//) && 
			do {
				$field =~ s/^\s+|\s+$//g; # trim leading and trailing whitespace
	            $field =~ /(\w*)\s*(.*)/s;
	            my $pName = $1;
	            my $pDesc = $2;
	            my $param = HeaderDoc::MinorAPIElement->new();
	            $param->outputformat($self->outputformat);
	            $param->name($pName);
	            $param->discussion($pDesc);
	            $self->addTaggedParameter($param);
# my $name = $self->name();
# print "Adding $pName : $pDesc in $name\n";
# my $class = ref($self) || $self;
# print "class is $class\n";
				last SWITCH;
			};
			($field =~ s/^return\s+//) && do {$self->result($field); last SWITCH;};
			($field =~ s/^result\s+//) && do {$self->result($field); last SWITCH;};
			# my $filename = $HeaderDoc::headerObject->filename();
			my $filename = $self->filename();
			my $linenum = $self->linenum();
			print "$filename:$linenum:Unknown field in Method comment: $field\n";
		}
	}
}

# sub getAPINameAndDisc {
    # my $line = shift;
    # my ($name, $disc, $operator);
    # # first, get rid of leading space
    # $line =~ s/^\s+//;
    # ($name, $disc) = split (/\s/, $line, 2);
    # if ($name =~ /operator/) {  # this is for operator overloading in C++
        # ($operator, $name, $disc) = split (/\s/, $line, 3);
        # $name = $operator." ".$name;
    # }
    # return ($name, $disc);
# }

sub setMethodDeclaration {
    my $self = shift;
    my ($dec) = @_[0];
    my $classType = @_[1];
    my ($retval);
    my $localDebug = 0;
    
    print "============================================================================\n" if ($localDebug);
    print "Raw declaration is: $dec\n" if ($localDebug);
    $self->declaration($dec);
    
    # regularize whitespace
    $dec =~ s/^\s+(.*)/$1/; # remove leading whitespace
    $dec =~ s/\t/ /g;
    $dec =~ s/</&lt;/g;
    $dec =~ s/>/&gt;/g;
    
	my $newdec = "";
	my @paramElements = split(/\:/, $dec);
	my $paramCount = 0;
	foreach my $paramTriple (@paramElements) {
		my $elementCount = 0;
		print "    paramTriple is |$paramTriple|\n" if ($localDebug);
		$paramTriple =~ s/ +/ /; # regularize spaces
		$paramTriple =~ s/^ +//; # remove leading whitespace
		$paramTriple =~ s/\) ?/\) /; # temporarily put spaces around the type declaration
		$paramTriple =~ s/ ?\(/ \(/; # for processing -- will be removed below

		my @paramParts = split(/ /, $paramTriple);
		foreach my $part (@paramParts) {
			if (($paramCount < $#paramElements || $#paramElements == 0) && $elementCount == $#paramParts) {
				if ($#paramElements == 0) {
					$part = "<B>$part</B>";
				} else {
					$part = "<B>$part:</B>";
				}	
			}	
			if (($paramCount > 0) && 
			      ((($paramCount < $#paramElements) && ($elementCount == $#paramParts - 1)) || (($paramCount == $#paramElements) && ($elementCount == $#paramParts)))) {
				$part = "<I>$part</I>";
			}
			$elementCount++;
			$newdec .= "$part ";
			#print "$newdec\n";
		}
		$paramCount++;
	}       
	
    # remove spaces around type declarations--that is around parens
    $newdec =~ s/\s+\(/(/g;
    $newdec =~ s/\)\s+/)/g;
    # reestablish space after - or +
    $newdec =~ s/^-/- /;
    $newdec =~ s/^\+/+ /;
    
    if ($newdec =~ /^\+/) {
    	$self->setIsInstanceMethod("NO");
    } elsif ($newdec =~ /^-/) {
    	$self->setIsInstanceMethod("YES");
    } else {
	# my $filename = $HeaderDoc::headerObject->filename();
	my $filename = $self->filename();
	my $linenum = $self->linenum();
        print "$filename:$linenum:Cannot determine whether method is class or instance method:\n";
        print "$filename:$linenum:        $newdec\n";
    	$self->setIsInstanceMethod("UNKNOWN");
    }
    
	if ($self->outputformat() eq "html") {
	    $retval = "<tt>$newdec</tt><br>\n";
	} elsif ($self->outputformat() eq "hdxml") {
	    $retval = "$newdec";
	} else {
	    print "UNKNOWN OUTPUT FORMAT!";
	    $retval = "$newdec";
	}
    print "Formatted declaration is: $retval\n" if ($localDebug);
    print "============================================================================\n" if ($localDebug);

    my $originaldec = $self->declaration();
    $self->declarationInHTML($originaldec);
    # $self->declarationInHTML($retval);
    return $retval;
}


sub XMLdocumentationBlock {
    my $self = shift;
	my $name = $self->name();
	my $desc = $self->discussion();
	my $abstract = $self->abstract();
	my $availability = $self->availability();
	my $updated = $self->updated();
	my $declaration = $self->declarationInHTML();
	my $declarationRaw = $self->declaration();
	my @params = $self->taggedParameters();
	my $result = $self->result();
	my $group = $self->group();
    # my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();
    my $owner = $self->apiOwner();
    my $contentString;
    my $className= 'UNKNOWN_CLASSNAME';
    	
    if ($owner->can("className")) {  # to get the class name from Category objects
    	$className = $owner->className();
    } else {
    	$className = $owner->name();
    }
    
    # my $filename = $HeaderDoc::headerObject->filename();
    my $filename = $self->filename();
    my $linenum = $self->linenum();
    print "$filename:$linenum:Warning: couldn't determine owning class/protocol for method: $name\n" if ($className eq 'UNKNOWN_CLASSNAME');

	my $methodType = $self->getMethodType($declarationRaw);
	my $uid = $self->apiuid($methodType); # "//$apiUIDPrefix/occ/$methodType/$className/$name";
	# registerUID($uid);
	$contentString .= "<method id=\"$uid\">\n";

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
	my $arrayLength = @params;
	if ($arrayLength > 0) {
		my $paramContentString;
		foreach my $element (@params) {
			my $pName = $element->name();
			my $pDesc = $element->discussion();
			if (length ($pName)) {
				$paramContentString .= "<parameter><name>$pName</name><desc>$pDesc</desc></parameter>\n";
			}
		}
		if (length ($paramContentString)){
			$contentString .= "<parameterlist>\n";
				$contentString .= $paramContentString;
			$contentString .= "</parameterlist>\n";
		}
	}
	if (length($result)) {
		$contentString .= "<result>$result</result>\n";
	}
	$contentString .= "</method>\n";
	return $contentString;
}

sub getMethodType {
	my $self = shift;
	my $filename = $self->filename();
	my $linenum = $self->linenum();
	my $declaration = shift;
	my $methodType = "";
		
	if ($declaration =~ /^\s*-/) {
	    $methodType = "instm";
	} elsif ($declaration =~ /^\s*\+/) {
	    $methodType = "clm";
	} elsif ($declaration =~ /#define/) {
	    $methodType = "defn";
	} else {
		my $filename = $HeaderDoc::headerObject->filename();
		if (!$HeaderDoc::ignore_apiuid_errors) {
			print "$filename:$linenum:Unable to determine whether declaration is for an instance or class method[method].\n";
			print "$filename:$linenum:     '$declaration'\n";
		}
		# We have to take an educated guess so the UID is legal
		$methodType = "instm";
	}
	return $methodType;
}

sub printObject {
    my $self = shift;
 
    print "Method\n";
    $self->SUPER::printObject();
    print "Result: $self->{RESULT}\n";
}

1;

