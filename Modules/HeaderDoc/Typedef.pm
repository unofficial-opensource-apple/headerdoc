#! /usr/bin/perl
#
# Class name: Typedef
# Synopsis: Holds typedef info parsed by headerDoc
#
# Author: Matt Morse (matt@apple.com)
# Last Updated: $Date: 2004/02/19 22:56:33 $
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
package HeaderDoc::Typedef;

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
    $self->{RESULT} = undef;
    $self->{FIELDS} = ();
    $self->{ISFUNCPTR} = 0;
    $self->{ISENUMLIST} = 0;
}

sub clone {
    my $self = shift;
    my $clone = undef;
    if (@_) {
	$clone = shift;
    } else {
	$clone = HeaderDoc::Typedef->new();
    }

    $self->SUPER::clone($clone);

    # now clone stuff specific to function

    $clone->{RESULT} = $self->{RESULT};
    $clone->{FIELDS} = $self->{FIELDS};
    $clone->{ISFUNCPTR} = $self->{ISFUNCPTR};
    $clone->{ISENUMLIST} = $self->{ISENUMLIST};

    return $clone;
}


sub result {
    my $self = shift;
    
    if (@_) {
        $self->{RESULT} = shift;
    }
    return $self->{RESULT};
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
    my $localDebug = 0;
    if (@_) { 
	foreach my $field (@_) {
		print "added field $field->{NAME} ($field->{TYPE})\n" if ($localDebug);
		push(@{$self->{FIELDS}}, $field);
	}
        # push (@{$self->{FIELDS}}, @_);
    }
    return @{ $self->{FIELDS} };
}

sub isFunctionPointer {
    my $self = shift;

    if (@_) {
        $self->{ISFUNCPTR} = shift;
    }
    return $self->{ISFUNCPTR};
}

sub isEnumList {
    my $self = shift;

    if (@_) {
        $self->{ISENUMLIST} = shift;
    }
    return $self->{ISENUMLIST};
}


sub processTypedefComment {
    my $self = shift;
    my $fieldArrayRef = shift;
    my @fields = @$fieldArrayRef;
    my $lastField = scalar(@fields);
    my $fieldCounter = 0;
    my $localDebug = 0;
    
    while ($fieldCounter < $lastField) {
        my $field = $fields[$fieldCounter];
        SWITCH: {
            ($field =~ /^\/\*\!/)&& do {last SWITCH;}; # ignore opening /*!
            ($field =~ s/^(typedef|function)(\s+)/$2/) && 
                do {
                    my ($name, $disc);
                    ($name, $disc) = &getAPINameAndDisc($field); 
                    $self->name($name);
                    if (length($disc)) {$self->discussion($disc);};
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
            ($field =~ s/^field\s+//) &&
                do {
                    $field =~ s/^\s+|\s+$//g;
                    $field =~ /(\w*)\s*(.*)/s;
                    my $fName = $1;
                    my $fDesc = $2;
                    my $fObj = HeaderDoc::MinorAPIElement->new();
	            $fObj->outputformat($self->outputformat);
                    $fObj->name($fName);
                    $fObj->discussion($fDesc);
                    $fObj->type("field");
                    $self->addField($fObj);
                    print "Adding field for typedef.  Field name: $fName.\n" if ($localDebug);
                    last SWITCH;
                };
            ($field =~ s/^constant\s+//) &&
                do {
                    $self->isEnumList(1);
                    $field =~ s/^\s+|\s+$//g;
                    $field =~ /(\w*)\s*(.*)/s;
                    my $fName = $1;
                    my $fDesc = $2;
                    my $fObj = HeaderDoc::MinorAPIElement->new();
	            $fObj->outputformat($self->outputformat);
                    $fObj->name($fName);
                    $fObj->discussion($fDesc);
                    $fObj->type("constant");
                    $self->addConstant($fObj);
                    # print "Adding constant for enum.  Constant name: $fName.\n" if ($localDebug);
                    last SWITCH;
                };
            # To handle callbacks and their params and results, have to set up loop
            ($field =~ s/^callback\s+//) &&
                do {
                    $field =~ s/^\s+|\s+$//g;
                    $field =~ /(\w*)\s*(.*)/s;
                    my $cbName = $1;
                    my $cbDesc = $2;
                    my $callbackObj = HeaderDoc::MinorAPIElement->new();
	            $callbackObj->outputformat($self->outputformat);
                    $callbackObj->name($cbName);
                    $callbackObj->discussion($cbDesc);
                    $callbackObj->type("callback");
                    # now get params and result that go with this callback
                    print "Adding callback.  Callback name: $cbName.\n" if ($localDebug);
                    $fieldCounter++;
                    while ($fieldCounter < $lastField) {
                        my $nextField = $fields[$fieldCounter];
                        print "In callback: next field is '$nextField'\n" if ($localDebug);
                        
                        if ($nextField =~ s/^param\s+//) {
                            $nextField =~ s/^\s+|\s+$//g;
                            $nextField =~ /(\w*)\s*(.*)/s;
                            my $paramName = $1;
                            my $paramDesc = $2;
                            $callbackObj->addToUserDictArray({"$paramName" => "$paramDesc"});
                        } elsif ($nextField eq "result") {
                            $nextField =~ s/^\s+|\s+$//g;
                            $nextField =~ /(\w*)\s*(.*)/s;
                            my $resultName = $1;
                            my $resultDesc = $2;
                            $callbackObj->addToUserDictArray({"$resultName" => "$resultDesc"});
                        } else {
                            last;
                        }
                        $fieldCounter++;
                    }
                    $self-> addField($callbackObj);
                    print "Adding callback to typedef.  Callback name: $cbName.\n" if ($localDebug);
                    last SWITCH;
                };
            # param and result have to come last, since they should be handled differently, if part of a callback
            # which is inside a struct (as above).  Otherwise, these cases below handle the simple typedef'd callback 
            # (i.e., a typedef'd function pointer without an enclosing struct.
            ($field =~ s/^param\s+//) && 
                do {
                    $self->isFunctionPointer(1);
                    $field =~ s/^\s+|\s+$//g;
                    $field =~ /(\w*)\s*(.*)/s;
                    my $fName = $1;
                    my $fDesc = $2;
                    my $fObj = HeaderDoc::MinorAPIElement->new();
	            $fObj->outputformat($self->outputformat);
                    $fObj->name($fName);
                    $fObj->discussion($fDesc);
                    $fObj->type("funcPtr");
                    $self->addField($fObj);
                    print "Adding param for function-pointer typedef.  Param name: $fName.\n" if ($localDebug);
                    last SWITCH;
                };
            ($field =~ s/^result\s+// || s/^return\s+//) && 
                do {
                    $self->isFunctionPointer(1);
                    $self->result($field);
                    last SWITCH;
                };
	    # my $filename = $HeaderDoc::headerObject->name();
	    my $filename = $self->filename();
	    my $linenum = $self->linenum();
            print "$filename:$linenum:Unknown field in Typedef comment: $field\n";
        }
        $fieldCounter++;
    }
}

sub setTypedefDeclaration {
    my $self = shift;
    my $dec = shift;
    my $decType;
    my $localDebug = 0;
    my $filename = $self->filename();
    my $linenum = 0;

    my $pound = 0;
    my $firstword = $dec;
    $firstword =~ s/^\s*//s;
    if ($firstword =~ s/^#//s) { $pound = 1; };
    $firstword =~ s/^\s*(\w+).*/$1/s;
    if ($pound) { $firstword = "#".$firstword; }

    # if (!($firstword eq "typedef")) {
	# warn("$filename:$linenum:Typedef declaration does not start with typedef\n");
	# warn("(First word is $firstword.)  Output may be broken.\n");
    # }

    if ($dec =~ /typedef(\s+\w+)*\s+\{/) {
	if ($self->isFunctionPointer()) {
	    # Somebody put in an @param instead of an @field
	    $self->isFunctionPointer(0);
	    warn("$filename:$linenum:Typedef markup invalid.  Non-callback typedefs\n");
	    warn("should use  \@field, not \@param.\n");
	}
    }

    $self->declaration($dec);
    
    print "============================================================================\n" if ($localDebug);
    print "Raw declaration is: $dec\n" if ($localDebug);
    
    # if ($dec =~/{/ || $dec =~/enum/ || $dec =~/struct/) { # typedef'd struct of anything
    if ($dec =~/\)\s*\(/ || $dec =~/\)\(/) { # typedef'd function pointer, in the form type (*name)(args)
        $decType = "funcPtr";
	my $test = $dec;
	$test =~s/^\s*typedef\s*(.*)\s*\(.*\)\s*\(.*\)\s*;\s*$/$1/s;
	if ($test eq $dec) { $decType = "struct"; }
	else {
	    print "test is $test, dec is $dec\n" if ($localDebug);
	    my $count = 0;
	    while ($test =~ /\{/g) { $count++; };
	    print "count is $count\n" if ($localDebug);
	    while ($test =~ /\}/g) { $count--; };
	    print "count is $count\n" if ($localDebug);
	    if ($count != 0) {$decType = "struct"; };
	}
    } else {          # simple function pointer
        $decType = "struct";
    }
    
    if ($decType eq "struct") {
        print "processing struct-like typedef\n" if ($localDebug); 
	    # $dec =~ s/\t/  /g;

	    # my $newdec = $self->structformat($dec, 0);
	    # $dec = $newdec;

	    if (length ($dec)) {$dec = "<pre>\n$dec</pre>\n";};
	} elsif ($decType eq "funcPtr") {
        print "processing funcPtr-like typedef\n" if ($localDebug); 
		if ($dec =~ /^EXTERN_API_C/) {
	        $dec =~ s/^EXTERN_API_C\(\s*(\w+)\s*\)(.*)/$1 $2/;
	    }

# print "DEC1: $dec\n";

	    $dec =~ s/</&lt;/g;
	    $dec =~ s/>/&gt;/g;
my $keepdec = $dec;
	    my $preOpeningParen = $dec;
	    $preOpeningParen =~ s/^\s+//m; # remove leading whitespace
	    # $preOpeningParen =~ s/(\w[^(]+)\(([^)]+)\)\s*;/$1/;
	    $preOpeningParen =~ s/(.*)\(.*;/$1/s;

	    my $withinParens = $dec;
	    $withinParens =~ s/.*?\(.*\)\s*\((.*)\).*;/$1/s;

	    my @preParenParts = split ('(\(.*\)\s\()(.*)\);', $preOpeningParen);

	    # my @preParenParts = split ('\s+', $preOpeningParen);
	    # &printArray(@preParenParts);
	    my $funcName = pop @preParenParts;

	    # my $return = join (' ', @preParenParts);
	    my $return = $funcName;
	    $return =~ s/(.*)\(.*/$1/s;
	    $return =~ s/^\s*//s;
	    $return =~ s/\s*$//s;
	    $funcName =~ s/.*\((.*)\)/$1/s;
	    $funcName =~ s/^\s*//s;
	    $funcName =~ s/\s*$//s;

	    my $remainder = $withinParens;

	    my @parensElements = split(/,/, $remainder);
	    
	    # eliminate this, unless we want to format args and their types separately
# 	    my @paramNames;
# 	    foreach my $element (@parensElements) {
# 	        my @paramElements = split(/\s+/, $element);
# 	        my $paramName = $paramElements[$#paramElements];
# 	        if ($paramName ne "void") { # some programmers write myFunc(void)
# 	            push(@paramNames, $paramName);
# 	        }
# 	    }
	    my $longstring = "";
            foreach my $element (@parensElements) {
		$element =~s/\n/ /g;
		$element =~s/^\s*//smg;
		$element =~s/\s*$//smg;
		if ($longstring eq "") {
		    $longstring = "\n&nbsp;&nbsp;&nbsp;&nbsp;$element";
		} else {
		    $longstring = "$longstring,<BR>\n&nbsp;&nbsp;&nbsp;&nbsp;$element";
		}
            }
	    # $dec = "<tt>$return <b>$funcName</b> ($remainder);</tt><br>\n";
	    if ($remainder =~/^\s*$/ || $remainder =~/^\s*void\s*$/) {
		if ($self->outputformat() eq "html") {
	            $dec = "<tt>$return (<b>$funcName</b>) (void);</tt><br>\n";
		} elsif ($self->outputformat() eq "hdxml") {
	            $dec = "$return (<funcname>$funcName</funcname>) (void);\n";
		} else {
		    print "UNKNOWN OUTPUT FORMAT!\n";
	            $dec = "$return (<funcname>$funcName</funcname>) (void);\n";
		}
	    } else {
		if ($self->outputformat() eq "html") {
	            $dec = "<tt>$return (<b>$funcName</b>) (<BR>$longstring<BR>);</tt><br>\n";
		} elsif ($self->outputformat() eq "hdxml") {
	            $dec = "$return (<funcname>$funcName</funcname>) (<argstring>$longstring</argstring>);\n";
		} else {
		    print "UNKNOWN OUTPUT FORMAT!\n";
	            $dec = "$return (<funcname>$funcName</funcname>) (<argstring>$longstring</argstring>);\n";
		}
	    }
	}
    print "Typedef: returning declaration:\n\t|$dec|\n" if ($localDebug);
    print "============================================================================\n" if ($localDebug);

    my $declaration = $self->declaration();
    $dec = $declaration;

    $self->declarationInHTML($dec);
    return $dec;
}


sub XMLdocumentationBlock {
    my $self = shift;
    my $name = $self->name();
    my $abstract = $self->abstract();
    my $availability = $self->availability();
    my $updated = $self->updated();
    my $desc = $self->discussion();
    my $result = $self->result();
    my $declaration = $self->declarationInHTML();
    my $group = $self->group();
    my @fields = $self->fields();
    my $fieldHeading;
    my $contentString;
    # my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();
    
    SWITCH: {
        if ($self->isFunctionPointer()) {$fieldHeading = "Parameter Descriptions"; last SWITCH; }
        if ($self->isEnumList()) {$fieldHeading = "Constants"; last SWITCH; }
        $fieldHeading = "Field Descriptions";
    }

    my $type = "simple";
    if ($self->isFunctionPointer()) {
	$type = "funcPtr";
    }
    my $uid = $self->apiuid("tdef"); # "//$apiUIDPrefix/c/tdef/$name";
    # registerUID($uid);
    $contentString .= "<typedef id=\"$uid\" type=\"$type\">\n"; # apple_ref marker
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
            my $fType = $element->type();
            
            if (($fType eq 'field') || ($fType eq 'constant') || ($fType eq 'funcPtr')){
                $contentString .= "<field type=\"$fType\"><name>$fName</name><description>$fDesc</description></field>\n";
            } elsif ($fType eq 'callback') {
                my @userDictArray = $element->userDictArray(); # contains elements that are hashes of param name to param doc
                my $paramString;
                foreach my $hashRef (@userDictArray) {
                    while (my ($param, $disc) = each %{$hashRef}) {
                        $paramString .= "<ref><parameter>$param</parameter><discussion>$disc</discussion></ref>\n";
                    }
                    if (length($paramString)) {$paramString = "<dl>\n".$paramString."\n</dl>\n";};
                }
                $contentString .= "<field type=\"$fType\"><name>$fName</name><description>$fDesc</description><reflist>$paramString</reflist></field>\n";
            } else {
		# my $filename = $HeaderDoc::headerObject->name();
		my $filename = $self->filename();
		my $linenum = $self->linenum();
                print "$filename:$linenum:warning: Typedef field with name $fName has unknown type: $fType\n";
            }
        }
        
        $contentString .= "</fieldlist>\n";
    }
    if (length($result)) {
        $contentString .= "<result>$result</result>\n";
    }
    $contentString .= "</typedef>\n";
    return $contentString;
}


sub printObject {
    my $self = shift;
 
    print "Typedef\n";
    $self->SUPER::printObject();
    SWITCH: {
        if ($self->isFunctionPointer()) {print "Parameter Descriptions:\n"; last SWITCH; }
        if ($self->isEnumList()) {print "Constants:\n"; last SWITCH; }
        print "Field Descriptions:\n";
    }

    my $fieldArrayRef = $self->{FIELDS};
    if ($fieldArrayRef) {
        my $arrayLength = @{$fieldArrayRef};
        if ($arrayLength > 0) {
            &printArray(@{$fieldArrayRef});
        }
    }
    print "is function pointer: $self->{ISFUNCPTR}\n";
    print "is enum list: $self->{ISENUMLIST}\n";
    print "\n";
}

1;

