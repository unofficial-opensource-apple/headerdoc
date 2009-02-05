#! /usr/bin/perl
#
# Class name: Function
# Synopsis: Holds function info parsed by headerDoc
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
package HeaderDoc::Function;

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
    $self->{RESULT} = undef;
    $self->{CONFLICT} = 0;
}

sub clone {
    my $self = shift;
    my $clone = undef;
    if (@_) {
	$clone = shift;
    } else {
	$clone = HeaderDoc::Function->new();
    }

    $self->SUPER::clone($clone);

    # now clone stuff specific to function

    $clone->{RESULT} = $self->{RESULT};
    $clone->{CONFLICT} = $self->{CONFLICT};

    return $clone;
}


sub result {
    my $self = shift;
    
    if (@_) {
        $self->{RESULT} = shift;
    }
    return $self->{RESULT};
}


sub processFunctionComment {
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
			($field =~ s/^function(\s+)/$1/) && 
			do {
				my ($name, $disc);
				($name, $disc) = &getAPINameAndDisc($field); 
				$self->name($name);
				if (length($disc)) {$self->discussion($disc);};
				last SWITCH;
			};
			($field =~ s/^serialData\s+//i) && do {$self->attribute("Serial Data", $field, 1); last SWITCH;};
			($field =~ s/^abstract\s+//) && do {$self->abstract($field); last SWITCH;};
			($field =~ s/^throws\s+//) && do {$self->throws($field); last SWITCH;};
			($field =~ s/^exception\s+//) && do {$self->throws($field); last SWITCH;};
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
			($field =~ s/^templatefield\s+//) && do {
					$self->attributelist("Template Field", $field);
                                        last SWITCH;
			};
			($field =~ s/^param\s+//) && 
			do {
				$field =~ s/^\s+|\s+$//g; # trim leading and trailing whitespace
	            # $field =~ /(\w*)\s*(.*)/s;
		    $field =~ /(\S*)\s*(.*)/s;
	            my $pName = $1;
	            my $pDesc = $2;
	            my $param = HeaderDoc::MinorAPIElement->new();
	            $param->outputformat($self->outputformat);
	            $param->name($pName);
	            $param->discussion($pDesc);
	            $self->addTaggedParameter($param);
				last SWITCH;
			};
			($field =~ s/^return\s+//) && do {$self->result($field); last SWITCH;};
			($field =~ s/^result\s+//) && do {$self->result($field); last SWITCH;};
			# my $filename = $HeaderDoc::headerObject->filename();
			my $filename = $self->filename();
			my $linenum = $self->linenum();
			print "$filename:$linenum:Unknown field in Function comment: $field\n";
		}
	}
}

# Yikes!  This shouldn't be here!
# 
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

sub setFunctionDeclaration {
    my $self = shift;
    my ($dec) = @_;
    my ($retval);
    my $localDebug = 0;
    my $noparens = 0;
    
    print "============================================================================\n" if ($localDebug);
    print "Raw declaration is: $dec\n" if ($localDebug);
    $self->declaration($dec);

    $self->declarationInHTML($dec);
    return $dec;

    # Throw all this away.
    
    #catch the case where this is a function-like macro
    if ($dec =~/^#define/) {
	# remove braced part
	$dec =~ s/(#define\s+\w+\s*\(.*\))\s+\{.*?\}\s*$/$1/sg;

        print "returning #define macro with declaration |$dec|\n" if ($localDebug);
	if ($self->outputformat() eq "html") {
            $dec =~ s/\\\n/\\<br>&nbsp;/g;
    	    $self->declarationInHTML("<tt>$dec</tt><br>");
            return"<tt>$dec</tt><br>\n";
	} elsif (self->outputformat() eq "hdxml") {
            return"$dec";
	} else {
	    print "ERROR: UNKNOWN OUTPUT FORMAT!\n";
	}
    }
    # regularize whitespace
    $dec =~ s/^\s+(.*)/$1/; # remove leading whitespace
    $dec =~ s/ \t/ /g;
    $dec =~ s/</&lt;/g;
    $dec =~ s/>/&gt;/g;
    
    # remove return from parens of EXTERN_API(_C)(retval)
    if ($dec =~ /^EXTERN_API(_C)?/) {
        $dec =~ s/^EXTERN_API(_C)?\(([^)]+)\)(.*)/$2 $3/;
        $dec =~ s/^\s+//;
    }
    # remove CF_EXPORT and find return value
    $dec =~ s/^CF_EXPORT\s+(.*)/$1/;
    # print "   with CF_EXPORT removed: $dec\n" if ($localDebug);

    my $parenscheck = $dec;
    $parenscheck =~ s/\s//smg;
    $parenscheck =~ s/^[-+]//smg;
    $parenscheck =~ s/^\(.*?\)//smg;
    if ($parenscheck !~ /\(/) {
	print "noparens\n" if ($localDebug);;
	$noparens = 1;
    } else {
	print "PC: $parenscheck\n" if ($localDebug);;
    }
    
    my $preOpeningParen = $dec;
    $preOpeningParen =~ s/^\s+(.*)/$1/; # remove leading whitespace
    $preOpeningParen =~ s/(\w[^(]+)\(([^)]*)\)(.*;[^;]*)$/$1/s;
    my $withinParens = $2;
    my $postParens = $3;
    # print "-->|$preOpeningParen|\n" if ($localDebug);
    
    my @preParenParts = split ('\s+', $preOpeningParen);
    my $funcName = pop @preParenParts;
    my $return = join (' ', @preParenParts);

    my $remainder = $withinParens;
    my @parensElements = split(/,/, $remainder);
    
    # now get parameters
    my $longstring = "";
    my $position = 1;  
    foreach my $element (@parensElements) {
        $element =~ s/\n/ /g;
        $element =~ s/^\s+//;
        print "element->|$element|\n" if ($localDebug);
        my @paramElements = split(/\s+/, $element);
        my $paramName = pop @paramElements;
        my $type = join (" ", @paramElements);
        
        #test for pointer asterisks and move to type portion of parameter declaration
        if ($paramName =~ /^\*/) {
            $paramName =~ s/^(\*+)(\w+)/$2/;
            $type .= " $1";
        }
        
        if ($paramName ne "void") { # some programmers write myFunc(void)
            my $param = HeaderDoc::MinorAPIElement->new();
	    $param->outputformat($self->outputformat);
            $param->name($paramName);
            $param->position($position);
            $param->type($type);
            $self->addParsedParameter($param);
        }
        $position++;

	# print "element \"$element\".";
	$element =~s/^\s*//;
	$element =~s/\s+/ /g;
	$element =~s/\s*$//;
	if ($longstring eq "") {
	    $longstring = "\n&nbsp;&nbsp;&nbsp;&nbsp;$element";
	} else {
	    $longstring = "$longstring,\n&nbsp;&nbsp;&nbsp;&nbsp;$element";
	}
    }

    if ($postParens =~ /\(.*\)\s*;/smg) {
      my $longstringb;
      my $position;
      my $pointerparms = $postParens;
      $pointerparms =~ s/^\s*\(//;
      $pointerparms =~ s/\)\s*;\s*$//;
      my @parensElements = split(/,/, $pointerparms);
      foreach my $element (@parensElements) {
        $element =~ s/\n/ /g;
        $element =~ s/^\s+//;
        print "element->|$element|\n" if ($localDebug);
        my @paramElements = split(/\s+/, $element);
        my $paramName = pop @paramElements;
        my $type = join (" ", @paramElements);
        
        #test for pointer asterisks and move to type portion of parameter declaration
        if ($paramName =~ /^\*/) {
            $paramName =~ s/^(\*+)(\w+)/$2/;
            $type .= " $1";
        }
        
        if ($paramName ne "void") { # some programmers write myFunc(void)
            my $param = HeaderDoc::MinorAPIElement->new();
	    $param->outputformat($self->outputformat);
            $param->name($paramName);
            $param->position($position);
            $param->type($type);
            $self->addParsedParameter($param);
        }
        $position++;

	$element =~s/^\s*//;
	$element =~s/\s+/ /g;
	$element =~s/\s*$//;
	if ($longstringb eq "") {
	    $longstringb = "&nbsp;(\n&nbsp;&nbsp;&nbsp;&nbsp;$element";
	} else {
	    $longstringb = "$longstringb,\n&nbsp;&nbsp;&nbsp;&nbsp;$element";
	}
      }
      $longstringb .= "\n);\n";
      $postParens = $longstringb;
    }
    if (!($return eq "")) { $return .= " "; }
    if ($noparens) {
	$retval = "<tt>$return$funcName $postParens</tt><br>\n";
    } else {
      if ($remainder =~/^\s*$/ || $remainder =~/^\s*void\s*$/) {
	$retval = "<tt>$return$funcName (void)$postParens</tt><br>\n";
      } else {
	$retval = "<tt>$return$funcName ($longstring\n)$postParens</tt><br>\n";
      }
    }
    print "Function: $funcName -- returning declaration:\n\t|$retval|\n" if ($localDebug);
    print "============================================================================\n" if ($localDebug);
    my $origdec = $self->declaration();
    $retval = $origdec;
    $self->declarationInHTML($retval);
    return $retval;
}


sub XMLdocumentationBlock {
    my $self = shift;
    my $contentString;
    my $name = $self->name();
    my $desc = $self->discussion();
    my $throws = $self->XMLthrows();
    my $abstract = $self->abstract();
    my $availability = $self->availability();
    my $updated = $self->updated();
    my $declaration = $self->declarationInHTML();
    my @parsedparams = $self->parsedParameters();
    my @params = $self->taggedParameters();
    my $returntype = $self->returntype();
    my $result = $self->result();
    my $group = $self->group();
    my $attlists = $self->getAttributeLists();
    my $atts = $self->getAttributes();
    # my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();
    my $functype = "func";

    if ($self->isTemplate()) { $functype = "ftmplt"; }
    my $uid = $self->apiuid($functype); # "//$apiUIDPrefix/c/func/$name";

    # registerUID($uid);
    $contentString .= "<function id=\"$uid\">\n"; # apple_ref marker
    $contentString .= "<name>$name</name>\n";
    if (length($availability)) {
        $contentString .= "<availability>$availability</availability>\n";
    }
    if (length($updated)) {
        $contentString .= "<updated>$updated</updated>\n";
    }
    if (length($group)) {
	$contentString .= "<group>$group</group>\n";
    }
    if (length($abstract)) {
        $contentString .= "<abstract>$abstract</abstract>\n";
    }
    if (length($throws)) {
	$contentString .= "$throws\n";
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
    my $arrayLength = @parsedparams;
    if ($arrayLength > 0) {
        my $paramContentString;
        foreach my $element (@parsedparams) {
            my $pName = $element->name();
            my $pType = $element->type();

	    $pType =~ s/\s*$//s;
	    if ($pName =~ s/^\s*(\*+)\s*//s) {
		$pType .= " $1";
	    }

	    $pType = $self->textToXML($pType);
	    $pName = $self->textToXML($pName);

            if (length ($pName) || length($pType)) {
                $paramContentString .= "<parsedparameter><type>$pType</type><name>$pName</name></parsedparameter>\n";
            }
        }
        if (length ($paramContentString)){
	    $contentString .= "<parsedparameterlist>\n";
            $contentString .= $paramContentString;
	    $contentString .= "</parsedparameterlist>\n";
        }
    }
    if (length($atts)) {
	$contentString .= "<attributes>$atts</attributes>\n";
    }
    if (length($attlists)) {
	$contentString .= "<attributelists>$attlists</attributelists>\n";
    }
    if (length($returntype)) {
	$contentString .= "<returntype>$returntype</returntype>\n";
    }
    if (length($result)) {
        $contentString .= "<result>$result</result>\n";
    }
    $contentString .= "</function>\n";
    return $contentString;
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

sub printObject {
    my $self = shift;
 
    print "Function\n";
    $self->SUPER::printObject();
    print "Result: $self->{RESULT}\n";
}


1;

