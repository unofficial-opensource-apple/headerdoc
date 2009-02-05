#! /usr/bin/perl -w
#
# Class name: HeaderElement
# Synopsis: Root class for Function, Typedef, Constant, etc. -- used by HeaderDoc.
#
# Author: Matt Morse (matt@apple.com)
# Last Updated: $Date: 2004/02/27 01:07:07 $
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

package HeaderDoc::HeaderElement;

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc printArray printHash registerUID registerUID quote parseTokens);
use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.20';

sub new {
    my($param) = shift;
    my($class) = ref($param) || $param;
    my $self = {};
    
    bless($self, $class);
    $self->_initialize();
    # Now grab any key => value pairs passed in
    my (%attributeHash) = @_;
    foreach my $key (keys(%attributeHash)) {
        my $ucKey = uc($key);
        $self->{$ucKey} = $attributeHash{$key};
    }
    return ($self);
}

sub _initialize {
    my($self) = shift;
    $self->{ABSTRACT} = undef;
    $self->{DISCUSSION} = undef;
    $self->{DECLARATION} = undef;
    $self->{DECLARATIONINHTML} = undef;
    $self->{OUTPUTFORMAT} = undef;
    $self->{FILENAME} = undef;
    $self->{NAME} = undef;
    $self->{RAWNAME} = undef;
    $self->{GROUP} = $HeaderDoc::globalGroup;
    $self->{THROWS} = undef;
    $self->{XMLTHROWS} = undef;
    $self->{UPDATED} = undef;
    $self->{LINKAGESTATE} = undef;
    $self->{ACCESSCONTROL} = undef;
    $self->{AVAILABILITY} = "";
    $self->{LANG} = $HeaderDoc::lang;
    $self->{SUBLANG} = $HeaderDoc::sublang;
    $self->{SINGLEATTRIBUTES} = ();
    $self->{LONGATTRIBUTES} = ();
    $self->{ATTRIBUTELISTS} = undef;
    $self->{APIOWNER} = $HeaderDoc::currentClass;
    $self->{APIUID} = undef;
    $self->{ORIGCLASS} = "";
    $self->{ISTEMPLATE} = 0;
    $self->{VALUE} = "UNKNOWN";
    $self->{RETURNTYPE} = "";
    $self->{TAGGEDPARAMETERS} = ();
    $self->{PARSEDPARAMETERS} = ();
    $self->{CONSTANTS} = ();
    $self->{LINENUM} = 0;
}

my %CSS_STYLES = ();

sub clone {
    my $self = shift;
    my $clone = undef;
    if (@_) {
	$clone = shift;
    } else {
	$clone = $self->new();
    }

    # $self->SUPER::clone($clone);

    # now clone stuff specific to header element

    $clone->{ABSTRACT} = $self->{ABSTRACT};
    $clone->{DISCUSSION} = $self->{DISCUSSION};
    $clone->{DECLARATION} = $self->{DECLARATION};
    $clone->{DECLARATIONINHTML} = $self->{DECLARATIONINHTML};
    $clone->{OUTPUTFORMAT} = $self->{OUTPUTFORMAT};
    $clone->{FILENAME} = $self->{FILENAME};
    $clone->{NAME} = $self->{NAME};
    $clone->{RAWNAME} = $self->{RAWNAME};
    $clone->{GROUP} = $self->{GROUP};
    $clone->{THROWS} = $self->{THROWS};
    $clone->{XMLTHROWS} = $self->{XMLTHROWS};
    $clone->{UPDATED} = $self->{UPDATED};
    $clone->{LINKAGESTATE} = $self->{LINKAGESTATE};
    $clone->{ACCESSCONTROL} = $self->{ACCESSCONTROL};
    $clone->{AVAILABILITY} = $self->{AVAILABILITY};
    $clone->{LANG} = $self->{LANG};
    $clone->{SUBLANG} = $self->{SUBLANG};
    $clone->{SINGLEATTRIBUTES} = $self->{SINGLEATTRIBUTES};
    $clone->{LONGATTRIBUTES} = $self->{LONGATTRIBUTES};
    $clone->{ATTRIBUTELISTS} = $self->{ATTRIBUTELISTS};
    $clone->{APIOWNER} = $self->{APIOWNER};
    $clone->{APIUID} = $self->{APIUID};
    $clone->{ORIGCLASS} = $self->{ORIGCLASS};
    $clone->{ISTEMPLATE} = $self->{ISTEMPLATE};
    $clone->{VALUE} = $self->{VALUE};
    $clone->{RETURNTYPE} = $self->{RETURNTYPE};
    $clone->{TAGGEDPARAMETERS} = ();
    if ($self->{TAGGEDPARAMETERS}) {
        my @params = @{$self->{TAGGEDPARAMETERS}};
        foreach my $param (@params) {
	    my $cloneparam = $param->clone();
	    push(@{$clone->{TAGGEDPARAMETERS}}, $cloneparam);
	    $cloneparam->apiOwner($clone);
	}
    }
    $clone->{PARSEDPARAMETERS} = ();
    if ($self->{PARSEDPARAMETERS}) {
        my @params = @{$self->{PARSEDPARAMETERS}};
        foreach my $param (@params) {
	    my $cloneparam = $param->clone();
	    push(@{$clone->{PARSEDPARAMETERS}}, $cloneparam);
	    $cloneparam->apiOwner($clone);
        }
    }
    $clone->{CONSTANTS} = ();
    if ($self->{CONSTANTS}) {
        my @params = @{$self->{CONSTANTS}};
        foreach my $param (@params) {
	    my $cloneparam = $param->clone();
	    push(@{$clone->{CONSTANTS}}, $cloneparam);
	    $cloneparam->apiOwner($clone);
	}
    }

    $clone->{LINENUM} = $self->{LINENUM};

    return $clone;
}


sub origClass {
    my $self = shift;
    if (@_) {
	my $newowner = shift;
	$self->{ORIGCLASS} = $newowner;
    }
    return $self->{ORIGCLASS};
}

sub constants {
    my $self = shift;
    if (@_) { 
        @{ $self->{CONSTANTS} } = @_;
    }
    # foreach my $const (@{ $self->{CONSTANTS}}) {print $const->name()."\n";}
    ($self->{CONSTANTS}) ? return @{ $self->{CONSTANTS} } : return ();
}

sub addConstant {
    my $self = shift;
    if (@_) { 
        push (@{$self->{CONSTANTS}}, @_);
    }
    return @{ $self->{CONSTANTS} };
}

sub isTemplate {
    my $self = shift;
    if (@_) {
        $self->{ISTEMPLATE} = shift;
    }
    return $self->{ISTEMPLATE};
}

# /*! @function inheritDoc
#     @abstract Parent discussion for inheritance
#     @discussion We don't want to show this, so we can't use an
#        attribute.  This is private.
#  */
sub inheritDoc {
    my $self = shift;

    if (@_) {
        my $inheritDoc = shift;
        $self->{INHERITDOC} = $inheritDoc;
    }
    return $self->{INHERITDOC};
}

# /*! @function linenum
#     @abstract line number where a declaration began
#     @discussion We don't want to show this, so we can't use an
#        attribute.  This is private.
#  */
sub linenum {
    my $self = shift;

    if (@_) {
        my $linenum = shift;
        $self->{LINENUM} = $linenum;
    }
    return $self->{LINENUM};
}

# /*! @function value
#     @abstract Value for constants, variables, etc.
#     @discussion We don't want to show this, so we can't use an
#        attribute.  This is private.
#  */
sub value {
    my $self = shift;

    if (@_) {
        my $value = shift;
        $self->{VALUE} = $value;
    }
    return $self->{VALUE};
}

sub outputformat {
    my $self = shift;

    if (@_) {
        my $outputformat = shift;
        $self->{OUTPUTFORMAT} = $outputformat;
    } else {
    	my $o = $self->{OUTPUTFORMAT};
		return $o;
	}
}

sub filename {
    my $self = shift;

    if (@_) {
        my $filename = shift;
        $self->{FILENAME} = $filename;
    } else {
    	my $n = $self->{FILENAME};
		return $n;
	}
}

sub name {
    my $self = shift;
    my $localDebug = 0;

    my($class) = ref($self) || $self;

    print "$class\n" if ($localDebug);

    if (@_) {
        my $name = shift;
	my $oldname = $self->{NAME};
	my $filename = $self->filename();
	my $linenum = $self->linenum();
	my $class = ref($self) || $self;

	if (!($class eq "HeaderDoc::Header") && ($oldname && length($oldname))) {
		# Don't warn for headers, as they always change if you add
		# text after @header.  Also, don't warn if the new name
		# contains the entire old name, to avoid warnings for
		# multiword names.  Otherwise, warn the user because somebody
		# probably put multiple @function tags in the same comment
		# block or similar....

		if ($name !~ /$oldname/) {
			if (!$HeaderDoc::ignore_apiuid_errors) {
				warn("$filename:$linenum:Name being changed ($oldname -> $name)\n");
			}
		} elsif (($class eq "HeaderDoc::CPPClass" || $class =~ /^ObjC/) && $name =~ /:/) {
			warn("$filename:$linenum:Class name contains colon, which is probably not what you want.\n");
		}
	}

	$name =~ s/\n$//sg;
	$name =~ s/\s$//sg;

        $self->{NAME} = $name;
    }

    my $n = $self->{NAME};

    if (($class eq "HeaderDoc::Function") || 
	($class eq "HeaderDoc::Method")) {
	  my @params = $self->taggedParameters();
	  my $arrayLength = @params;
	  if ($self->conflict() && $arrayLength) {
		# print "CONFLICT for $n!\n";
		$n .= "(";
		my $first = 1;
		foreach my $param (@params) {
			if (!$first) {
				$n .= ", ".$param->name();
			} else {
				$n .= $param->name();
				$first = 0;
			}
		}
		$n .= ")";
	  }
    }

    return $n;
}

# /*! @function see
#     @abstract Add see/seealso (JavaDoc compatibility enhancement)
#  */
sub see {
    my $self = shift;
    my $liststring = shift;
    my $type = "See";

    # Is it a see or seealso?

    if ($liststring =~ s/^seealso\s+//s) {
	$type = "See Also";
    } else {
	$liststring =~ s/^see\s+//s;
    }

    my @list = split(/\s+/, $liststring);
    foreach my $see (@list) {
	my $apiref = $self->genRef("", $see, $see);
	my $apiuid = $apiref;
	$apiuid =~ s/^<!--\s*a\s+logicalPath\s*=\s*\"//s;
	$apiuid =~ s/"\s*-->\s*$see\s*<!--\s*\/a\s*-->//s;
	$self->attributelist($type, "$see $apiuid");
    }

}

sub rawname {
    my $self = shift;
    my $localDebug = 0;

    if (@_) {
	my $name = shift;
	$self->{RAWNAME} = $name;
	print "RAWNAME: $name\n" if ($localDebug);
    }

    my $n = $self->{RAWNAME};
    if (!($n) || !length($n)) {
	$n = $self->{NAME};
    }


    return $n;
}

sub group {
    my $self = shift;

    if (@_) {
        my $group = shift;
        $self->{GROUP} = $group;
    } else {
    	my $n = $self->{GROUP};
		return $n;
	}
}

# /*! @function attribute
#     @abstract This function adds an attribute for a class or header.
#     @param name The name of the attribute to be added
#     @param attribute The contents of the attribute
#     @param long 0 for single line, 1 for multi-line.
#  */
sub attribute {
    my $self = shift;
    my $name = shift;
    my $attribute = shift;
    my $long = shift;
    my $localDebug = 0;

    my %attlist = ();
    if ($long) {
        if ($self->{LONGATTRIBUTES}) {
	    %attlist = %{$self->{LONGATTRIBUTES}};
        }
    } else {
        if ($self->{SINGLEATTRIBUTES}) {
	    %attlist = %{$self->{SINGLEATTRIBUTES}};
        }
	$attribute =~ s/\n/ /sg;
	$attribute =~ s/^\s*//s;
	$attribute =~ s/\s*$//s;
    }

    %attlist->{$name}=$attribute;

    if ($long) {
        $self->{LONGATTRIBUTES} = \%attlist;
    } else {
        $self->{SINGLEATTRIBUTES} = \%attlist;
    }

    my $temp = $self->getAttributes(2);
    print "Attributes: $temp\n" if ($localDebug);;

}

#/*! @function getAttributes
#    @param long 0 for short only, 1 for long only, 2 for both
# */
sub getAttributes
{
    my $self = shift;
    my $long = shift;
    my %attlist = ();
    my $localDebug = 0;
    my $xml = 0;

    my $apiowner = $self->apiOwner();
    if ($apiowner->outputformat() eq "hdxml") { $xml = 1; }

    my $retval = "";
    if ($long != 1) {
        if ($self->{SINGLEATTRIBUTES}) {
	    %attlist = %{$self->{SINGLEATTRIBUTES}};
        }

        foreach my $key (sort keys %attlist) {
	    my $value = %attlist->{$key};
	    my $newatt = $value;
	    if ($key eq "Superclass" && !$xml) {
		# my $ref = $self->make_classref($value);
		# $newatt = "<!-- a logicalPath=\"$ref\" -->$value<!-- /a -->";
		$newatt = $self->genRef("class", $value, $value); # @@@
	    } else {
		print "KEY: $key\n" if ($localDebug);
	    }
	    if ($xml) {
		$retval .= "<attribute><name>$key</name><value>$newatt</value></attribute>\n";
	    } else {
		$retval .= "<b>$key:</b> $newatt<br>\n";
	    }
        }
    }

    if ($long != 0) {
        if ($self->{LONGATTRIBUTES}) {
	    %attlist = %{$self->{LONGATTRIBUTES}};
        }

        foreach my $key (sort keys %attlist) {
	    my $value = %attlist->{$key};
	    if ($xml) {
		$retval .= "<longattribute><name>$key</name><value>$value</value></longattribute>\n";
	    } else {
		$retval .= "<b>$key:</b>\n\n<p>$value<p>\n";
	    }
        }
    }

    return $retval;
}

sub checkShortLongAttributes
{
    my $self = shift;
    my $name = shift;
    my $localDebug = 0;

    my %singleatts = ();
    if ($self->{SINGLEATTRIBUTES}) {
	%singleatts = %{$self->{SINGLEATTRIBUTES}};
    }
    my %longatts = ();
    if ($self->{LONGATTRIBUTES}) {
	%longatts = %{$self->{LONGATTRIBUTES}};
    }

    foreach my $key (keys %singleatts) {
	if ($key eq $name) {return %singleatts->{$key};}
    }
    foreach my $key (keys %longatts) {
	if ($key eq $name) {return %longatts->{$key};}
    }
    return 0;
}

sub checkAttributeLists
{
    my $self = shift;
    my $name = shift;
    my $localDebug = 0;

    my %attlists = ();
    if ($self->{ATTRIBUTELISTS}) {
	%attlists = %{$self->{ATTRIBUTELISTS}};
    }

    # print "list\n";
    my $retval = "";
    foreach my $key (sort keys %attlists) {
	if ($key eq $name) { return 1; }
    }
    return 0;
}

sub getAttributeLists
{
    my $self = shift;
    my $localDebug = 0;
    my $xml = 0;

    my $apiowner = $self->apiOwner();
    if ($apiowner->outputformat() eq "hdxml") { $xml = 1; }

    my %attlists = ();
    if ($self->{ATTRIBUTELISTS}) {
	%attlists = %{$self->{ATTRIBUTELISTS}};
    }

    # print "list\n";
    my $retval = "";
    foreach my $key (sort keys %attlists) {
	if ($xml) {
	    $retval .= "<listattribute><name>$key</name><list>\n";
	} else {
	    $retval .= "<b>$key:</b><dl>\n";
	}
	print "key $key\n" if ($localDebug);
	my @list = @{%attlists->{$key}};
	foreach my $item (@list) {
	    print "item: $item\n" if ($localDebug);
	    my ($name, $disc) = &getAPINameAndDisc($item);

	    if ($key eq "Included Defines") {
		my $apiref = $self->apiref("macro", $name);
		$name .= "$apiref";
	    }
	    if (($key eq "See Also" || $key eq "See") && !$xml) {
		$disc =~ s/^\s*//sg;
		$disc =~ s/\s*$//sg;
		$name =~ s/\cD/ /sg;
		$name = "<!-- a logicalPath=\"$disc\" -->$name<!-- /a -->";
		$disc = "";
	    }
	    if ($xml) {
		$retval .= "<item><name>$name</name><value>$disc</value></item>";
	    } else {
		$retval .= "<dt>$name</dt><dd>$disc</dd>";
	    }
	}
	if ($xml) {
	    $retval .= "</list></listattribute>\n";
	} else {
	    $retval .= "</dl>\n";
	}
    }
    # print "done\n";
    return $retval;
}

# /*! @function attributelist
#     @abstract Add an attribute list.
#     @param name The name of the list
#     @param attribute
#          A string in the form "term description..."
#          containing a term and description to be inserted
#          into the list named by name.
#  */
sub attributelist {
    my $self = shift;
    my $name = shift;
    my $attribute = shift;

    my %attlists = ();
    if ($self->{ATTRIBUTELISTS}) {
        %attlists = %{$self->{ATTRIBUTELISTS}};
    }

    my @list = ();
    if (%attlists->{$name}) {
	@list = @{%attlists->{$name}};
    }
    push(@list, $attribute);

    %attlists->{$name}=\@list;
    $self->{ATTRIBUTELISTS} = \%attlists;
    # print "AL = $self->{ATTRIBUTELISTS}\n";

    # print $self->getAttributeLists()."\n";
}

sub apiOwner {
    my $self = shift;
    if (@_) {
	my $temp = shift;
	$self->{APIOWNER} = $temp;
    }
    return $self->{APIOWNER};
}

sub apiref {
    my $self = shift;
    my $filename = $self->filename();
    my $linenum = $self->linenum();
    my $type = shift;
    my $apiowner = $self->apiOwner();
    my $owningclass = ref($apiowner) || $self;
    my $paramSignature = "";
    if (@_) {
	$paramSignature = shift;
    }

    # Don't provide API refs for inherited data or functions.
    if ($self->origClass() ne "") { return ""; }

    if ($paramSignature =~ /[ <>\s\n\r]/) {
	warn("$filename:$linenum:apiref: bad signature \"$paramSignature\".  Dropping ref.\n");
	return "";
    }

    my $uid = $self->apiuid($type, $paramSignature);
    my $ret = "";
    if (length($uid)) {
	my $name = $self->name();
	if ($self->can("rawname")) { $name = $self->rawname(); }
	my $extendedname = $name;
	if ($owningclass ne "HeaderDoc::Header") {
		$extendedname = $apiowner->rawname() . "::" . $name;
	}
	$extendedname =~ s/\s//sg;
	$extendedname =~ s/<.*?>//sg;
        $extendedname =~ s/;//sg;
	$ret .= "<!-- headerDoc=$type; name=$extendedname --><a name=\"$uid\"></a>\n";
    }
    return $ret;
}

sub apiuid {
    my $self = shift;
    my $type = "AUTO";
    my $paramSignature_or_alt_define_name = "";
    my $filename = $self->filename();
    my $linenum = $self->linenum();

    if (@_) {
	$type = shift;
	if (@_) {
		$paramSignature_or_alt_define_name = shift;
	}
    } else {
	return $self->{APIUID};
    }

    my $name = $self->name();
    my $localDebug = 0;
    my $className; 
    my $lang = $self->sublang();
    my $class = ref($self) || $self;

    if (!($self->can("conflict")) || ($self->can("conflict") && !($self->conflict()))) {
	$name = $self->rawname();
	if ($class eq "HeaderDoc::ObjCCategory") {
		# Category names are in the form "ClassName (DelegateName)"
		if ($name =~ /\s*\w+\s*\(.+\).*/) {
			$name =~ s/\(.*//;
		}
	}
	# Silently drop spaces.
	$name =~ s/\s//sg;
	$name =~ s/<.*?>//sg;
	if ($name =~ /[ \(\)<>\s\n\r]/) {
	    if (!$HeaderDoc::ignore_apiuid_errors) {
		warn("$filename:$linenum:apiref: bad name \"$name\".  Dropping ref.\n");
	    }
	    return "";
	}
    } else {
	my $apiOwner = $self->apiOwner();
	my $apiOwnerClass = ref($apiOwner) || $apiOwner;
	if ($apiOwnerClass eq "HeaderDoc::CPPClass") {
		$name = $self->rawname();
	} else {
		$name =~ s/ //sg;
	}
	# Silently drop spaces.
	$name =~ s/\s//sg;
	$name =~ s/<.*?>//sg;
	if ($name =~ /[\s\n\r]/) {
	    if (!$HeaderDoc::ignore_apiuid_errors) {
		warn("$filename:$linenum:apiref: bad name \"$name\".  Dropping ref.\n");
	    }
	    return "";
	}
    }

    my $parentClass = $self->apiOwner();
    my $parentClassType = ref($parentClass) || $parentClass;
    if ($parentClassType eq "HeaderDoc::Header") {
	# Generate requests with sublang always (so that, for
	# example, a c++ header can link to a class from within
	# a typedef declaration.

	# Generate anchors (except for class anchors) with lang
	# if the parent is a header, else sublang for stuff
	# within class braces so that you won't get name
	# resolution conflicts if something in a class has the
	# same name as a generic C entity, for example.

	if (!($class eq "HeaderDoc::CPPClass" || $class =~ /^HeaderDoc::ObjC/)) {
	    $lang = $self->lang();
	}
    }

    if ($lang eq "C") { $lang = "c"; }

    $name =~ s/\n//smg;

    # my $lang = "c";
    # my $class = ref($HeaderDoc::APIOwner) || $HeaderDoc::APIOwner;

    # if ($class =~ /^HeaderDoc::CPPClass$/) {
        # $lang = "cpp";
    # } elsif ($class =~ /^HeaderDoc::ObjC/) {
        # $lang = "occ";
    # }

    print "LANG: $lang\n" if ($localDebug);
    # my $classHeaderObject = HeaderDoc::APIOwner->headerObject();
    # if (!$classHeaderObject) { }
    if ($parentClassType eq "HeaderDoc::Header") {
        # We're not in a class.  We used to give the file name here.

	if (!$HeaderDoc::headerObject) {
		die "headerObject undefined!\n";
	}
        # $className = $HeaderDoc::headerObject->name();
	# if (!(length($className))) {
		# die "Header Name empty!\n";
	# }
	$className = "";
    } else {
        # We're in a class.  Give the class name.
        $className = $parentClass->name();
	if (length($name)) { $className .= "/"; }
    }
    $className =~ s/\s//sg;
    $className =~ s/<.*?>//sg;

    # Macros are not part of a class in any way.
    my $class = ref($self) || $self;
    if ($class eq "HeaderDoc::PDefine") {
	$className = "";
	if ($paramSignature_or_alt_define_name) {
		$name = $paramSignature_or_alt_define_name;
		$name = "";
	}
    }

# warn("genRefSub: \"$lang\" \"$type\" \"$name\" \"$className\" \"$paramSignature_or_alt_define_name\"\n");

    my $uid = $self->genRefSub($lang, $type, $name, $className, $paramSignature_or_alt_define_name);

    $self->{APIUID} = $uid;
    registerUID($uid);
    return $uid;

    # my $ret .= "<a name=\"$uid\"></a>\n";
    # return $ret;
}

# /*! @function genRefSub
#     @param lang Language
#     @param type
#     @param name
#     @param className
#  */
sub genRefSub
{
    my $self = shift;
    my $lang = shift;
    my $type = shift;
    my $name = shift;
    my $className = shift;
    my $paramSignature = "";
    if (@_) {
	$paramSignature = shift;
    }

    my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();    
    my $localDebug = 0;

    if ($lang eq "C") { $lang = "c"; }

    my $uid = "//$apiUIDPrefix/$lang/$type/$className$name$paramSignature";
    return $uid;
}

sub throws {
    my $self = shift;

    if (@_) {
	my $new = shift;
	$new =~ s/\n//smg;
        $self->{THROWS} .= "<li>$new</li>\n";
	$self->{XMLTHROWS} .= "<throw>$new</throw>\n";
	# print "Added $new to throw list.\n";
    }
    # print "dumping throw list.\n";
    if (length($self->{THROWS})) {
    	return ("<ul>\n" . $self->{THROWS} . "</ul>");
    } else {
	return "";
    }
}

sub XMLthrows {
    my $self = shift;
    my $string = $self->{XMLTHROWS};

    my $ret;

    if (length($string)) {
	$ret = "<throwlist>\n$string</throwlist>\n";
    } else {
	$ret = "";
    }
    return $ret;
}

sub abstract {
    my $self = shift;

    if (@_) {
        $self->{ABSTRACT} = $self->linkfix(shift);
    }
    return $self->{ABSTRACT};
}

sub XMLabstract {
    my $self = shift;

    if (@_) {
        $self->{ABSTRACT} = shift;
    }
    return $self->{ABSTRACT};
}


sub discussion {
    my $self = shift;

    if (@_) {
	my $olddisc = $self->{DISCUSSION};
	if ($olddisc && length($olddisc)) {
		$olddisc =~ s/<br>/\n/smg;

		my $oldname = $self->name();

		if ($olddisc =~ /\n/) {
		    my @nlcheckarray = split(/\n/, $olddisc);
		    my $done_one = 0;
		    my $firstline = "";
		    foreach my $nlcheck (@nlcheckarray) {
			if ($done_one) {
				$nlcheck =~ s/\n//smg;
				$nlcheck =~ s/\s//smg;
				if (length($nlcheck)) {
					my $filename = $self->filename();
					my $linenum = $self->linenum();
					warn("$filename:$linenum:Multiple discussions found for $oldname.  Ignoring first.\n");
					# It's bad, so don't include it at all.
					$firstline = "";
					last;
				}
			} else {
				$firstline = $nlcheck;
				$done_one = 1;
			}
		    }
		    if (length($firstline)) {
			$self->name($oldname." ".$firstline);
		    }
		} else {
		    $self->name($oldname." ".$olddisc);
		}
	}

        my $discussion = "";
        $discussion = shift;
        $discussion =~ s/\n\n/<br>\n/g;
        $self->{DISCUSSION} = $self->linkfix($discussion);
    }
    return $self->{DISCUSSION};
}

sub XMLdiscussion {
    my $self = shift;

    if (@_) {
        my $discussion = "";
        $discussion = shift;
        # $discussion =~ s/\n\n/<br>\n/g;
        $self->{DISCUSSION} = $discussion;
    }
    return $self->{DISCUSSION};
}


sub declaration {
    my $self = shift;
    # my $dec = $self->declarationInHTML();
    # remove simple markup that we add to declarationInHTML
    # $dec =~s/<br>/\n/gi;
    # $dec =~s/<font .*?>/\n/gi;
    # $dec =~s/<\/font>/\n/gi;
    # $dec =~s/<(\/)?tt>//gi;
    # $dec =~s/<(\/)?b>//gi;
    # $dec =~s/<(\/)?pre>//gi;
    # $dec =~s/\&nbsp;//gi;
    # $dec =~s/\&lt;/</gi;
    # $dec =~s/\&gt;/>/gi;
    # $self->{DECLARATION} = $dec;  # don't really have to have this ivar
    if (@_) {
	$self->{DECLARATION} = shift;
    }
    return $self->{DECLARATION};
}

sub exp_structformat
{
    my $self = shift;
    my $declaration = shift;
    my $trim_leading = shift;

    my $newdec = "";
    $declaration =~ s/\n/ /smg;
    $declaration =~ s/\s+/ /sg;
print "DEC: $declaration\n";

    my @words = split(/(\W)/, $declaration);
    my @newwords = ( "" );

    foreach my $word(@words) {
	if (!length($word)) { next; }
	# print "WORD: \"$word\"\n";
	my $lastword = pop(@newwords);
	push(@newwords, $lastword);
	SWITCH: {
	    ($word =~ /\s/) && do {
			if ($lastword eq ";") { $word = "\n"; }
			print "SPC\n";
			push(@newwords, " ");
			last SWITCH;
		};
	    ($word =~ /[;,]/) && do {
		print "SEP\n";
		my $lastword = pop(@newwords);
		if ($lastword ne " ") {
			push(@newwords, $lastword);
		}
		push(@newwords, $word);
		last SWITCH;
		};
	    ($word =~ /[=+-\/]/) && do {
		print "OP\n";
		my $lastword = pop(@newwords);
		push(@newwords, $lastword);
		if ($lastword =~ /(\w|\s)/) {
			push(@newwords, " ");
		}
		push(@newwords, $word);
		last SWITCH;
		};
	    ($word =~ /[\{\}]/) && do {
			print "BRC\n";
			push(@newwords, $word);
			last SWITCH;
		};
	    {
		print "TXT\n";
		push(@newwords, $word);
	    }
	}
    }
    foreach my $word (@newwords) {
	print "NW: \"$word\"\n";
	$newdec .= $word;
    }

    return $newdec;
}

sub structformat
{
    my $self = shift;
    my $dec = shift;
    my $trim_leading = shift;
    my $localDebug = 0;

    if ($dec !~ /{/) { return $dec; }

    $dec =~ s/\t/  /g;
    # $dec =~ s/^\s+(.*)/$1/; # remove leading whitespace
    if ($trim_leading) {
	$dec =~ s/^\s+//smg; # remove leading whitespace
    }
    $dec =~ s/</&lt;/g;
    $dec =~ s/>/&gt;/g;

my $class = ref($self) || $self;
print "BEGIN $class\n" if ($localDebug);
print "$dec\nEND\n" if ($localDebug);

    my $decline = $dec;
    $decline =~ s/^(.*?)\s*{.*/$1/smg;
    my $endline = $dec;
    $endline =~ s/.*}//sg;
    my $mid = $dec;
    print "mid $mid\n" if ($localDebug);
    # $mid =~ s/{\s*(.*)\s*}.*?/$1/smg;
print "DECLINE = $decline\n" if ($localDebug);

    my $declineregexp = quote($decline); # "\Q$decline\E";
    my $endlineregexp = quote($endline); # "\Q$endline\E";

    $mid =~ s/^$declineregexp.*?{//sm;
    $mid =~ s/}\s*$endlineregexp$//sm;
    $mid =~ s/^\n*//smg;
    $mid =~ s/\n+$/\n/smg;
    print "mid $mid\n" if ($localDebug);

    my $newdec = "$decline {\n";

    my @splitlines = split ('\n', $mid);

    my $indent = 1;
    foreach my $line (@splitlines) {
	print "LINE: $line\n" if ($localDebug);
        if ($trim_leading) { $line =~ s/^\s*//; }
        if ($line =~ /}/) { $indent--; }
        my $i = $indent; while ($i) { $newdec .= "    "; $i--;}
        if ($line =~ /{/) { $indent++; }
        $newdec .= $line."\n";
    }
    if ("$endline" eq ";") {
        $newdec .= "}".$endline;
    } else {
        $newdec .= "} ".$endline;
    };

    print "new dec is:\n$newdec\n" if ($localDebug);
    $dec = $newdec;

    # if (length ($dec)) {$dec = "<pre>\n$dec</pre>\n";};
    # print "DEC WAS $dec ENDDEC\n";

	# print "AIEEEE! $dec AIEEEE\n";
    $dec =~ s/\n+/\n/sg;

    return $dec;
}

# /*! @function defineColor
#     @abstract parse #define directives.  Coloring is impossible
#      without context, so just add dummy link resolver requests
#      for everything and his mother.
#     @param declaration
#  */
sub defineColor
{
    my $self = shift;
    my $declaration = shift;
    my $ret = "";

    # tokenizing parser
    # my @parts = split(/(\W)/, $declaration);
    my @parts = split(/(?<=\W)|(?=\W)/, $declaration);
    my @newparts = ();

    my $nextpartprepend = "";
    my $lastpart = "";
    foreach my $part (@parts) {
	# warn("PART: $part\n");
	if (length($nextpartprepend)) {
		$part = "$nextpartprepend$part";
	}
	if ($part eq ":") {
		if ($lastpart eq ":") {
			my $colon = pop(@newparts);
			my $lastwordpart = pop(@newparts);
			$nextpartprepend = "$lastwordpart::";
			# warn("FOUNDIT\n");
		} else {
			# warn("LP=$lastpart\n");
			push(@newparts, $lastpart);
			push(@newparts, $part);
		}
	} else {
		push(@newparts, $part);
	}
	$lastpart = $part;
    }

    # @@@ Add link requests @@@ #
    foreach my $part (@newparts) {
	if ($part =~ /\W/) {
	    $ret .= $part;
	} else {
	    # for now.
	    if ($part =~ /::/) {
		warn("classpart: $part");
	    }
	    $ret .= $part;
	}
    }
    return $ret;
}

# /*! @function complexTypeColor
#     @abstract parse data type declaration, adding coloration
#     @param declaration
#  */
sub complexTypeColor
{
    my $self = shift;
    my $class = ref($self) || $self;
    my $declaration = shift;
    my $localDebug = 0;
    my $lang = $self->lang();
    my $sublang = $self->sublang();
    my $filename = $HeaderDoc::headerObject->filename();
    my $name = $self->name();

    if ($class eq "HeaderDoc::PDefine") {
	return $self->defineColor($declaration);
    }

# if ($declaration =~ /_mediaPresent/) { # Uncomment to test coloring of a given declaration
	# warn("$name\n");
	# $localDebug = 1;
# }

    if (($class eq "HeaderDoc::PDefine") && ($self->isBlock)) {
	$self->isBlock(0);
	my @blockArray = ();
	my $curBlock = "";
        $declaration =~ s/<br>/\n/smig;
	my @lines = split(/\n/, $declaration);
        $declaration =~ s/<pre>//g;
        $declaration =~ s/<\/pre>//g;
	foreach my $line (@lines) {
	    if (!length($line)) {$curBlock .= "\n";}
	    elsif ($line =~ /\\\s*$/) {
		$curBlock .= $line;
	    } else {
		$curBlock .= "$line\n";
		push(@blockArray, $curBlock);
		$curBlock = "";
	    }
	}
	if ($curBlock) {
	    my $filename = $self->filename();
	    my $linenum = $self->linenum();
	    warn("$filename:$linenum:Illegal trailing backslash in define block\n");
	    push(@blockArray, $curBlock);
	}
	my $ret = "";
	foreach $curBlock (@blockArray) {
	    # warn("cB: $curBlock\n");
	    my $part .= $self->complexTypeColor($curBlock);
	    $part =~ s/<pre>//g;
	    $part =~ s/<\/pre>//g;
	    if ($part !~ /\n$/s) {
		$part .= "\n";
	    }
	    # warn("Final part was $part\n");
	    $ret .= $part;
	    # $ret .= "<BR>\n";
	}
	# warn("THIS: $ret\nENDTHIS\n");
	$self->isBlock(1);
	return "<pre>$ret</pre>\n";
    } # end if PDefine block

    # If we got here, we're not in a defineblock (or are in the
    # individual defines extracted from such a block).

    my $onelinedec = $declaration;
    $onelinedec =~ s/\\\s*$//smg;
    $onelinedec =~ s/\n//smg;
    $onelinedec =~ s/<pre>//smg;
    $onelinedec =~ s/<\/pre>//smg;
    $onelinedec =~ s/<tt>//smg;
    $onelinedec =~ s/<\/tt>//smg;
    warn("OLD: $onelinedec\n") if ($localDebug);
    if ($class eq "HeaderDoc::PDefine" && 0) {
	# replace a symbol with a function or similar
	my $firstpart = "";
	my $optsecondpart = "";
	my $thirdpart = "";
	my $fourthpart = "";
	if ($onelinedec =~ /#define\s+\w+\((\w|,|\s)+\)\s+\(/s) {
	    # #define name(args) (expression)
	    warn("case 1\n") if ($localDebug);
	    my $rmdefine = $onelinedec;
	    $rmdefine =~ s/^#define\s+//s;

	    my $firstpart = $rmdefine;
	    $firstpart =~ s/^(\w*).*/$1/sg;

	    my $rest = $rmdefine;
	    $rest =~ s/^$firstpart//sg; # safe because this is just letters & numbers.
	    my $ret = "<font class=\"keyword\">#define</font> ";
	    $ret .= "<font class=\"function\">$firstpart</font>";
	    warn("So far: $ret\n") if ($localDebug);
	    $ret .= $self->numcharstringcolor($rest);

	    warn("Returning $ret\n") if ($localDebug);
	    return "<pre>$ret</pre>";
	} elsif ($onelinedec =~ /#define\s+(\w+)\s*$/s) {
	    # #define name
	    warn("case 2\n") if ($localDebug);
	    $firstpart = $1;
	    $optsecondpart = $2;
	} elsif ($onelinedec =~ /#define\s+(\w+)\s+(\w+)\s*$/s) {
	    # #define name name_or_number
	    warn("case 3\n") if ($localDebug);
	    $firstpart = $1;
	    $optsecondpart = $2;
	} elsif ($onelinedec =~ /#define\s+(\w+)\s+(\(.*\))/s) {
	    # #define name (expression)
	    warn("case 4\n") if ($localDebug);
	    $firstpart = $1;
	    $thirdpart = $3;
	} elsif ($onelinedec =~ /#define\s+(\w+)\s*(\(.*\))\s+((\w|::)+)\s*(\(.*\))/s) {
	    # #define name(args) function(args)
	    $firstpart = $1;
	    $optsecondpart = $2;
	    $thirdpart = $3;
	    $fourthpart = $4;
	} elsif ($onelinedec =~ /#define\s+(\w+)\s+((\w|::)+)\s*(\(.*\))/s) {
	    # #define name function(args)
	    warn("case 5\n") if ($localDebug);
	    $firstpart = $1;
	    $optsecondpart = $2;
	    $thirdpart = $3;
	} elsif ($onelinedec =~ /^\s*#define\s+(\w+)\s+(\".*?\")\s*$/s) {
	    # #define name "string"
	    warn("case 6\n") if ($localDebug);
	    $firstpart = $1;
	    $fourthpart = $2;
	} else {
	    warn("case 7\n") if ($localDebug);
	}
	warn("FP: $firstpart\n") if ($localDebug);
	if (length($firstpart)) {
	warn("Point4\n") if ($localDebug);
	    # my $firstpart = $1;
	    # my $optsecondpart = $2;
	    # my $thirdpart = $3;
	    my $ret = "<font class=\"keyword\">#define</font> ";

	    if (length($fourthpart) && !length($thirdpart)) {
	warn("Point4y\n") if ($localDebug);
		$ret .= $self->numcharstringcolor($firstpart);
		$ret .= " ";
		$ret .= "<font class=\"string\">$fourthpart</font>";
	    } elsif (length($fourthpart)) {
	warn("Point4x\n") if ($localDebug);
		$ret .= "<font class=\"function\">$firstpart</font>(";
		$ret .= $self->numcharstringcolor($optsecondpart);
		$ret .= ") ";
		$ret .= $self->genRef("", $thirdpart,
			    "<font class=\"function\">$thirdpart</font>");
		$ret .= "(";
		$ret .= $self->numcharstringcolor($fourthpart);
		$ret .= ")\n";
	    } elsif (length($optsecondpart) && length($thirdpart)) {
	warn("Point4a\n") if ($localDebug);
	        my $funcpart = $optsecondpart . $thirdpart;
                $ret .= "<font class=\"function\">$firstpart</font> ";
                # my $tempdec .= $self->functionColor($funcpart);
	        # $tempdec =~ s/\n//g;
	        # $tempdec =~ s/<br>//g;
	        # $ret .= $self->numcharstringcolor($tempdec);
	        $ret .= $self->numcharstringcolor($funcpart);
	    } elsif (length($optsecondpart)) {
	warn("Point4b\n") if ($localDebug);
		$ret .= "<font class=\"var\">$firstpart</font> ";

		$ret .= $self->numcharstringcolor($optsecondpart);

	    } else {
	warn("Point4c\n") if ($localDebug);
	warn("OLD: $onelinedec /OLD\n") if ($localDebug);
	        $ret = $self->functionColor($declaration);
	    }
            return "<pre>$ret</pre>";
	}
    }
	warn("Point5\n") if ($localDebug);

    my $ret = $self->blockColor($declaration, 0);
    # warn("ENDCLASS\n");

    return $ret;
}

sub numcharstringcolor
{
	my $self = shift;
	my $string = shift;
	my $ret = "";
	my $localDebug = 0;

	my @words = split(/(\W)/, $string);
	foreach my $word (@words) {
	    print "WORD is $word\n" if ($localDebug);
	    my $value = $word;
	    my $tail = $value;

	    if ($word =~ /\W/) {
		$ret .= $word;
	    } elsif ($tail =~ s/^\s*(-|)(\d+)//s) {
		# $value =~ s/\s*//g;
		$value = "$1$2";

		if ($tail =~ s/^x//g) {
			$tail =~ s/((\d|a|b|c|d|e|f)+)//is;
			$value .= "x$1";
		}
		if ($tail =~ s/\.//g) {
			$tail =~ s/(\d+)//s;
			$value .= ".$1";
    		}
		if ($tail =~ s/^(f|ul|u|l)//is) {
			$value .= "$1";
		}
		$ret .= "<font class=\"number\">$value</font>$tail";
	    } else {
		my $parsed_quotes = $self->stringAndCharColor($value);
		$ret .= "$parsed_quotes";
	    }
	}
	return $ret;
}

# /*! @function genRef
#     @abstract generate a cross-reference request
#     @param keystring string containing the keywords, e.g. stuct, enum
#     @param namestring string containing the type name itself
#     @param linktext link text to generate
#  */
sub genRef
{
    my $self = shift;
    my $keystring = shift;
    my $name = shift;
    my $linktext = shift;
    my $filename = $self->filename();
    my $linenum = $self->linenum();
    my $tail = "";
    my $xml = 0;

    if ($self->outputformat() eq "hdxml") { $xml = 1; }

    # Generate requests with sublang always (so that, for
    # example, a c++ header can link to a class from within
    # a typedef declaration.  Generate anchors with lang
    # if the parent is a header, else sublang for stuff
    # within class braces so that you won't get name
    # resolution conflicts if something in a class has the
    # same name as a generic C entity, for example.

    my $lang = $self->sublang();

    if ($name =~ /^[\d\[\]]/) {
	# Silently fail for [4] and similar.
	return $linktext;
    }

    if (($name =~ /^[=|+-\/&^~!*]/) || ($name =~ /^\s*\.\.\.\s*$/)) {
	# Silently fail for operators
	# and varargs macros.

	return $linktext;
    }
    if (($name =~ /^\s*public:/) || ($name =~ /^\s*private:/) ||
	($name =~ /^\s*protected:/)) {
	# Silently fail for these, too.

	return $linktext;
    }
    if ($name =~ s/\)\s*$//) {
	if ($linktext =~ s/\)\s*$//) {
		$tail = ")";
	} else {
		warn("WARNING: Parenthesis in ref name, not in link text\n");
		warn("name: $name) linktext: $linktext\n");
	}
    }

    # I haven't found any cases where this would trigger a warning
    # that don't already trigger a warning elsewhere.
    my $testing = 0;
    if ($testing && ($name =~ /&/ || $name =~ /\(/ || $name =~ /\)/ || $name =~ /.:(~:)./ || $name =~ /;/ || $name eq "::" || $name =~ /^::/)) {
	my $classname = $self->name();
	my $class = ref($self) || $self;
	my $declaration = $self->declaration();
	if (($name eq "(") && $class eq "HeaderDoc::PDefine") {
		warn("FOOFOOFOO: bogus paren in #define\n");
	} elsif (($name eq "(") && $class eq "HeaderDoc::Function") {
		warn("FOOFOOFOO: bogus paren in function\n");
	} elsif ($class eq "HeaderDoc::Function") {
		warn("FUNCFUNC: bogus paren in function\n");
	} else {
		warn("BUGBUGBUG: $filename $classname $class $keystring generates bad crossreference ($name).  Dumping trace.\n");
		# my $declaration = $self->declaration();
		# warn("BEGINDEC\n$declaration\nENDDEC\n");
		$self->printObject();
	}
    }

    if ($name =~ /(.+)::(.+)/) {
	my $classpart = $1;
	my $type = $2;
	if ($linktext !~ /::/) {
		warn("$filename:$linenum:Bogus link text generated for item containing class separator.  Ignoring.\n");
	}
	my $ret = $self->genRef("class", $classpart, $classpart);
	$ret .= "::";

	# This is where it gets ugly.  C++ allows use of struct,
	# enum, and other similar types without preceding them
	# with struct, enum, etc....

	$classpart .= "/";

        my $ref1 = $self->genRefSub($lang, "instm", $type, $classpart);
        my $ref2 = $self->genRefSub($lang, "clm", $type, $classpart);
        my $ref3 = $self->genRefSub($lang, "func", $type, $classpart);
        my $ref4 = $self->genRefSub($lang, "ftmplt", $type, $classpart);
        my $ref5 = $self->genRefSub($lang, "defn", $type, "");
        my $ref6 = $self->genRefSub($lang, "macro", $type, "");
	# allow classes within classes for certain languages.
        my $ref7 = $self->genRefSub($lang, "cl", $type, $classpart);
        my $ref8 = $self->genRefSub($lang, "tdef", $type, "");
        my $ref9 = $self->genRefSub($lang, "tag", $type, "");
        my $ref10 = $self->genRefSub($lang, "econst", $type, "");
        my $ref11 = $self->genRefSub($lang, "struct", $type, "");
        my $ref12 = $self->genRefSub($lang, "data", $type, $classpart);
        my $ref13 = $self->genRefSub($lang, "clconst", $type, $classpart);
	if (!$xml) {
        	$ret .= "<!-- a logicalPath=\"$ref1 $ref2 $ref3 $ref4 $ref5 $ref6 $ref7 $ref8 $ref9 $ref10 $ref11 $ref12 $ref13\" -->$type<!-- /a -->";
	} else {
        	$ret .= "<hd_link logicalPath=\"$ref1 $ref2 $ref3 $ref4 $ref5 $ref6 $ref7 $ref8 $ref9 $ref10 $ref11 $ref12 $ref13\">$type</hd_link>";
	}

	return $ret.$tail;
    }

    my $ret = "";
    my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();    
    my $type = "";
    my $className = "";

    my $class_or_enum_check = " $keystring ";
    if ($lang eq "pascal") { $class_or_enum_check =~ s/\s+var\s+/ /sg; }
    if ($lang eq "MIG") { $class_or_enum_check =~ s/\s+(in|out|inout)\s+/ /sg; }
    $class_or_enum_check =~ s/\s+const\s+/ /sg;
    $class_or_enum_check =~ s/\s+static\s+/ /sg;
    $class_or_enum_check =~ s/\s+virtual\s+/ /sg;
    $class_or_enum_check =~ s/\s+auto\s+/ /sg;
    $class_or_enum_check =~ s/\s+extern\s+/ /sg;
    $class_or_enum_check =~ s/\s+__asm__\s+/ /sg;
    $class_or_enum_check =~ s/\s+__asm\s+/ /sg;
    $class_or_enum_check =~ s/\s+__inline__\s+/ /sg;
    $class_or_enum_check =~ s/\s+__inline\s+/ /sg;
    $class_or_enum_check =~ s/\s+inline\s+/ /sg;
    $class_or_enum_check =~ s/\s+register\s+/ /sg;
    $class_or_enum_check =~ s/\s+template\s+/ /sg;
    $class_or_enum_check =~ s/\s+unsigned\s+/ /sg;
    $class_or_enum_check =~ s/\s+signed\s+/ /sg;
    $class_or_enum_check =~ s/\s+volatile\s+/ /sg;
    $class_or_enum_check =~ s/\s+private\s+/ /sg;
    $class_or_enum_check =~ s/\s+protected\s+/ /sg;
    $class_or_enum_check =~ s/\s+public\s+/ /sg;
    $class_or_enum_check =~ s/\s+synchronized\s+/ /sg;
    $class_or_enum_check =~ s/\s+transient\s+/ /sg;
    $class_or_enum_check =~ s/\s*//smg;

    if (length($class_or_enum_check)) {
	SWITCH: {
	    ($keystring =~ /type/ && $lang eq "pascal") && do { $type = "tdef"; last SWITCH; };
	    ($keystring =~ /record/ && $lang eq "pascal") && do { $type = "struct"; last SWITCH; };
	    ($keystring =~ /procedure/ && $lang eq "pascal") && do { $type = "*"; last SWITCH; };
	    ($keystring =~ /of/ && $lang eq "pascal") && do { $type = "*"; last SWITCH; };
	    ($keystring =~ /typedef/) && do { $type = "tdef"; last SWITCH; };
	    (($keystring =~ /sub/) && ($lang eq "perl")) && do { $type = "*"; last SWITCH; };
	    ($keystring =~ /function/) && do { $type = "*"; last SWITCH; };
	    ($keystring =~ /typedef/) && do { $type = "tdef"; last SWITCH; };
	    ($keystring =~ /struct/) && do { $type = "tag"; last SWITCH; };
	    ($keystring =~ /union/) && do { $type = "tag"; last SWITCH; };
	    ($keystring =~ /operator/) && do { $type = "*"; last SWITCH; };
	    ($keystring =~ /enum/) && do { $type = "tag"; last SWITCH; };
	    ($keystring =~ /class/) && do { $type = "cl"; $className=$name; $name=""; last SWITCH; };
	    ($keystring =~ /#(define|ifdef|ifndef|if|endif|pragma|include|import)/) && do {
		    # Used to include || $keystring =~ /class/
		    # defines and similar aren't followed by a type
		    return $linktext.$tail;
		};
	    {
		$type = "";
		my $name = $self->name();
		warn "Unknown keystring ($keystring) in $name type link markup\n"; # @@@ FIX FORMAT
		return $linktext.$tail;
	    }
	}
	if ($type eq "*") {
	    # warn "Function requested with genRef.  This should not happen.\n";
	    # This happens now, at least for operators.

	    my $ref1 = $self->genRefSub($lang, "instm", $name, $className);
	    my $ref2 = $self->genRefSub($lang, "clm", $name, $className);
	    my $ref3 = $self->genRefSub($lang, "func", $name, $className);
	    my $ref4 = $self->genRefSub($lang, "ftmplt", $name, $className);
	    my $ref5 = $self->genRefSub($lang, "defn", $name, $className);
	    my $ref6 = $self->genRefSub($lang, "macro", $name, $className);

	    if (!$xml) {
	        return "<!-- a logicalPath=\"$ref1 $ref2 $ref3 $ref4 $ref5 $ref6\" -->$linktext<!-- /a -->".$tail;
	    } else {
	        return "<hd_link logicalPath=\"$ref1 $ref2 $ref3 $ref4 $ref5 $ref6\">$linktext</hd_link>".$tail;
	    }
	} else {
	    if (!$xml) {
	        return "<!-- a logicalPath=\"" . $self->genRefSub($lang, $type, $className, $name) . "\" -->$linktext<!-- /a -->".$tail;
	    } else {
	        return "<hd_link logicalPath=\"" . $self->genRefSub($lang, $type, $className, $name) . "\">$linktext</hd_link>".$tail;
	    }
	}
    } else {
	# We could be looking for a class or a typedef.  Unless it's local, put in both
	# and let the link resolution software sort it out.  :-)

        my $ref1 = $self->genRefSub($lang, "instm", $name, $className);
        my $ref2 = $self->genRefSub($lang, "clm", $name, $className);
        my $ref3 = $self->genRefSub($lang, "func", $name, $className);
        my $ref4 = $self->genRefSub($lang, "ftmplt", $name, $className);
        my $ref5 = $self->genRefSub($lang, "defn", $name, "");
        my $ref6 = $self->genRefSub($lang, "macro", $name, "");
        # allow classes within classes for certain languages.
        my $ref7 = $self->genRefSub($lang, "cl", $name, "");
        my $ref7a = $self->genRefSub($lang, "cl", $name, $className);
        my $ref8 = $self->genRefSub($lang, "tdef", $name, "");
        my $ref9 = $self->genRefSub($lang, "tag", $name, "");
        my $ref10 = $self->genRefSub($lang, "econst", $name, "");
        my $ref11 = $self->genRefSub($lang, "struct", $name, "");
        my $ref12 = $self->genRefSub($lang, "data", $name, $className);
        my $ref13 = $self->genRefSub($lang, "clconst", $name, $className);
	if (!$xml) {
            return "<!-- a logicalPath=\"$ref1 $ref2 $ref3 $ref4 $ref5 $ref6 $ref7 $ref7a $ref8 $ref9 $ref10 $ref11 $ref12 $ref13\" -->$linktext<!-- /a -->".$tail;
	} else {
            return "<hd_link logicalPath=\"$ref1 $ref2 $ref3 $ref4 $ref5 $ref6 $ref7 $ref7a $ref8 $ref9 $ref10 $ref11 $ref12 $ref13\">$linktext</hd_link>".$tail;
	}

    # return "<!-- a logicalPath=\"$ref1 $ref2 $ref3\" -->$linktext<!-- /a -->".$tail;
    }

}

# /*! @function keywords
#     @abstract returns all known keywords for the current language
#  */
sub keywords
{
    my $self = shift;
    my $class = ref($self) || $self;
    my $declaration = shift;
    my $functionBlock = shift;
    my $orig_declaration = $declaration;
    my $localDebug = 0;
    my $parmDebug = 0;
    my $lang = $self->lang();
    my $sublang = $self->sublang();
    # my $filename = $HeaderDoc::headerObject->filename();
    my $filename = $self->filename();
    my $linenum = $self->linenum();
    my $case_sensitive = 1;

    print "keywords\n" if ($localDebug);

    # print "Color\n" if ($localDebug);
    # print "lang = $HeaderDoc::lang\n";

    # Note: these are not all of the keywords of each language.
    # This should, however, be all of the keywords that can occur
    # in a function or data type declaration (e.g. the sort
    # of material you'd find in a header).  If there are missing
    # keywords that meet that criterion, please file a bug.

    my @CKeywords = ( 
	"auto", "const", "enum", "extern", "inline",
	"__inline__", "__inline", "__asm", "__asm__",
	"register", "signed", "static", "struct", "typedef",
	"union", "unsigned", "volatile", "#define",
	"#ifdef", "#ifndef", "#if", "#endif",
 	"#pragma", "#include", "#import" );
    my @CppKeywords = (@CKeywords,
	"class", 
	"friend",
	"namespace",
	"operator",
	"private",
	"protected",
	"public",
	"template",
	"virtual" );
    my @ObjCKeywords = (@CKeywords,
	"\@class",
	"\@interface",
	"\@protocol" );
    my @phpKeywords = @CKeywords;
    my @javaKeywords = (@CKeywords,
	"class", 
	"extends",
	"implements",
	"import",
	"instanceof",
	"interface",
	"native",
	"package",
	"private",
	"protected",
	"public",
	"strictfp",
	"super",
	"synchronized",
	"throws",
	"transient",
	"template",
	"volatile" );
    my @perlKeywords = ( "sub" );
    my @shellKeywords = ( "sub" );
    my @pascalKeywords = (
	"absolute", "abstract", "all", "and", "and_then",
	"array", "asm", "begin", "bindable", "case", "class",
	"const", "constructor", "destructor", "div", "do",
	"downto", "else", "end", "export", "file", "for",
	"function", "goto", "if", "import", "implementation",
	"inherited", "in", "inline", "interface", "is", "label",
	"mod", "module", "nil", "not", "object", "of", "only",
	"operator", "or", "or_else", "otherwise", "packed", "pow",
	"procedure", "program", "property", "qualified", "record",
	"repeat", "restricted", "set", "shl", "shr", "then", "to",
	"type", "unit", "until", "uses", "value", "var", "view",
	"virtual", "while", "with", "xor" );
    my @MIGKeywords = (
	"routine", "simpleroutine", "inout", "in", "out",
	"subsystem", "skip" );

    my $objC = 0;
    my @keywords = @CKeywords;
    # warn "Language is $lang, sublanguage is $sublang\n";

    if ($lang eq "C") {
	SWITCH: {
	    ($sublang eq "cpp") && do { @keywords = @CppKeywords; last SWITCH; };
	    ($sublang eq "C") && do { last SWITCH; };
	    ($sublang =~ "^occ") && do { @keywords = @ObjCKeywords; $objC = 1; last SWITCH; }; #occ, occCat
	    ($sublang eq "intf") && do { @keywords = @ObjCKeywords; $objC = 1; last SWITCH; };
	    ($sublang eq "MIG") && do { @keywords = @MIGKeywords; last SWITCH; };
	    warn "$filename:$linenum:Unknown language ($lang:$sublang)\n";
	}
    }
    if ($lang eq "Csource") {
	SWITCH: {
	    ($sublang eq "Csource") && do { last SWITCH; };
	    warn "$filename:$linenum:Unknown language ($lang:$sublang)\n";
	}
    }
    if ($lang eq "php") {
	SWITCH: {
	    ($sublang eq "php") && do { @keywords = @phpKeywords; last SWITCH; };
	    warn "$filename:$linenum:Unknown language ($lang:$sublang)\n";
	}
    }
    if ($lang eq "java") {
	SWITCH: {
	    ($sublang eq "java") && do { @keywords = @javaKeywords; last SWITCH; };
	    warn "$filename:$linenum:Unknown language ($lang:$sublang)\n";
	}
    }
    if ($lang eq "perl") {
	SWITCH: {
	    ($sublang eq "perl") && do { @keywords = @perlKeywords; last SWITCH; };
	    warn "$filename:$linenum:Unknown language ($lang:$sublang)\n";
	}
    }
    if ($lang eq "shell") {
	SWITCH: {
	    ($sublang eq "shell") && do { @keywords = @shellKeywords; last SWITCH; };
	    warn "$filename:$linenum:Unknown language ($lang:$sublang)\n";
	}
    }
    if ($lang eq "pascal") {
	@keywords = @pascalKeywords;
	$case_sensitive = 0;
    }

    # foreach my $keyword (@keywords) {
	# print "keyword $keyword\n";
    # }

    return ($case_sensitive, @keywords);
}

# /*! @function blockColor
#     @abstract does coloring of function & struct blocks
# */
sub blockColor
{
    my $self = shift;
    my $class = ref($self) || $self;
    my $declaration = shift;
    my $functionBlock = shift;
    my $orig_declaration = $declaration;
    my $preDebug =   0;
    my $localDebug = 0;
    my $parmDebug =  0;
    my $hangDebug =  0;
    my $lang = $self->lang();
    my $sublang = $self->sublang();
    my $filename = $HeaderDoc::headerObject->filename();
    my $starcolor = 1;
    my $pascal = 0;

    my ($case_sensitive, @keywords) = $self->keywords();
    my ($sotemplate, $eotemplate, $soc, $eoc, $ilc, $sofunction,
	$soprocedure, $sopreproc, $lbrace, $rbrace, $structname,
	$structisbrace) = parseTokens($lang, $sublang);

    my $socquot = quote($soc);
    my $eocquot = quote($eoc);
    my $ilcquot = quote($ilc);
    # print "NAME: ".$self->name."\n";

    my $objC = 0;
    if ($lang eq "C" && ($sublang =~ "^occ" || $sublang eq "intf")) {
	$objC = 1;
    }
    if ($lang eq "pascal") {
	$pascal = 1;
    }

    print "blockColor\n" if ($localDebug);

    # print "Color\n" if ($localDebug);
    # print "lang = $HeaderDoc::lang\n";

    $declaration =~ s/<br>/\n/smig;
    $declaration =~ s/&nbsp;/ /smig;

    my $tt = 0;
    my $pre = 0;

    # $declaration =~ s/^\s*//mg;
    # my $indentdec = $self->structformat($declaration, 0);
    # $declaration = $indentdec;

    my $prebracespart; my $inbracespart ; my $postbracespart;

print "declaration was\n$declaration\nEND\n" if ($localDebug);
    if ($declaration =~ s/^<pre>//smg) {
	$pre = 1;
	$declaration =~ s/<\/pre>$//smg;
    }
    if ($declaration =~ s/^<tt>//smg) {
	$tt = 1;
	$declaration =~ s/<\/tt>$//smg;
    }

    if ($tt) { $pre = 1; $tt = 0; }

    if ($functionBlock) {
	$declaration =~ s/\n+$/\n/smg;
    } else {
	$declaration =~ s/^\n//sg;
	$declaration =~ s/\n*$//sg;
    }
print "declaration is\n$declaration\nEND\n" if ($localDebug);

    my $splitchar = "(;|\n)";

    if ($functionBlock) {
	$splitchar = "(,|\n)";
    } else {
      SWITCH: {
	($class eq "HeaderDoc::Enum") && do { $splitchar = "(,|\n)"; last SWITCH; };
	($class eq "HeaderDoc::Typedef") && do {
		if ($declaration =~ /^typedef\s+enum/) {
			$splitchar = "(,|\n)"; last SWITCH;
		}
		if ($self->isFunctionPointer()) {
			$splitchar = "(,|\n)"; last SWITCH;
		}
	    };
      }
    }

    my $deFunBody = "";
    my $deFunTail = "";
    my $deFun = 0;

    if ($functionBlock) {
      if ($declaration =~ /^(.*?)\{(.*)\}(.*?)$/sm) {
       $deFunBody = $2;
       $deFunTail = $3;
       $declaration = $1;
       $deFun = 1;
      }
    }

    my $parenthesized = 1;;
    my $objCPrefix = "";
    my $parenReturnType = "";
    if ($functionBlock) {
        if ($objC) {
           if ($declaration =~ /^\s*([+-])\s*(.*?)$/s) {
               $objCPrefix = $1;
               print "olddec[objC] = $declaration\n" if ($localDebug);
               $declaration = $2;
               print "newdec[objC] = $declaration\n" if ($localDebug);
           }
        }

	print "objCPrefix: $objCPrefix\n" if ($localDebug);
    
        if ($declaration =~/^\((.*?)\)(.*)$/sm) {
           $parenReturnType = $1;
           print "olddec = $declaration\n" if ($localDebug);
           $declaration = $2;
           print "pRT = $parenReturnType\n" if ($localDebug);
           print "rest = $declaration\n" if ($localDebug);
        }
    }

    my $startParamChar = "{";
    my $endParamChar = "}";

    if ($functionBlock) {
	$startParamChar = "(";
	$endParamChar = ")";
    }

    my $startParamRegex="\\".$startParamChar;
    my $endParamRegex="\\".$endParamChar;

    if ($lang eq "pascal" && $class eq "HeaderDoc::Typedef") {
	$startParamChar="<font class=\"keyword\">record</font>";
	$startParamRegex="record";
	$endParamChar="<font class=\"keyword\">end</font>";
	$endParamRegex="end";
    }

    print "ParamBlock delimiters: $startParamChar $endParamChar\n" if ($localDebug);

    if ($declaration =~ /^(.*?)$startParamRegex(.*)$endParamRegex(.*?)$/s) {
	print "ParamBlock Found\n" if ($localDebug);
	$prebracespart = $1;
	$inbracespart = $2;
	$postbracespart = $3;
	$parenthesized = 1;
        if ($functionBlock) {
	  if ($declaration =~ /^(.*?)$startParamRegex(.*)$endParamRegex\s*$startParamRegex(.*)$endParamRegex(.*?)$/sm) {
	    print "Multiple ParamBlocks Found\n" if ($localDebug);
	    print "ParamBlock delimiters: $startParamChar $endParamChar\n" if ($localDebug);
            $inbracespart = $3;
            $postbracespart = $4;
            $prebracespart = "$1($2)";
	  }
        }
    } else {
	$prebracespart = $declaration;
	$inbracespart = "";
	$postbracespart = "";
	$parenthesized = 0;
    }
    # my $parenthesized = 1;
    # my $prebracespart = $declaration;
    # if (!($prebracespart =~ s/{.*//smg)) {
	# $parenthesized = 0;
    # }
# 
    # my $postbracespart = $declaration;
    # if (!($postbracespart =~ s/.*}//smg)) {
	# $parenthesized = 0;
    # }
# 
    # my $inbracespart;
    # if ($parenthesized) {
	# $inbracespart = $declaration;
	# $inbracespart =~ s/^$prebracespart.*?{//smg;
	# $inbracespart =~ s/}.*?$postbracespart$//smg;
	# $inbracespart =~ s/^\n*//smg;
	# $inbracespart =~ s/\n+$//smg;
	# # print "Dec: $declaration\n";
	# # print "IBP: $inbracespart\n";
    # } else {
	# $prebracespart = $declaration;
	# $inbracespart = "";
	# $postbracespart = "";
    # }
# 
    # # print "[1]: $prebracespart\n";
    # # print "[2]: $inbracespart\n";
    # # print "[3]: $postbracespart\n";
    # # print "end.\n";
# 
    # # my $newpre = $prebracespart;
    # # my $newin = $inbracespart;
    # my $newpost = $postbracespart;
# 
# 
# # OK
    # # $prebracespart =~ s/^\n*//sg;
    # $postbracespart =~ s/\n*$//sg;
# 

    # clean up case.

    if ($functionBlock) {
	if (!$deFun) { $postbracespart =~ s/\n*$//sg; }
    }
    # $prebracespart =~ s/^\s*//s;

    print "orig_DEC: $orig_declaration\n" if ($localDebug);
    print "DEC: $declaration\n" if ($localDebug);
    print "pre: $prebracespart\n" if ($localDebug);;
    print "in: $inbracespart\n" if ($localDebug);;
    print "post: $postbracespart\n" if ($localDebug);;

# colorize the pre-parenthesized part
    print("Point 1\n") if ($hangDebug);

    # my $prespacecount = ($prebracespart =~ tr/^\s//);
    my $initspace = "";
    while ($prebracespart =~ s/^\s//s) {
	$initspace .= " ";
	print "initspace = \"$initspace\"\n" if ($localDebug);
    }

    my $tailcomment = "";
    if (length($ilc)) {
	if ($prebracespart =~ s/$ilcquot(.*)$//s) {
	    $tailcomment .= "$ilc$1";
	}
    }
    if (length($soc) && length($eoc)) {
	if ($prebracespart =~ s/$socquot(.*)$eocquot//s) { # @@@ COMMENT
	    $tailcomment = "$soc$1$eoc".$tailcomment;
	}
    }

    my @words = split(/(\W)/s, $prebracespart);

    my $unbraced = 0;
    my $unbracetest = $inbracespart.$postbracespart;
    $unbracetest =~ s/\n*//smg;
    $unbracetest =~ s/\s*//smg;
    $unbracetest =~ s/;//smg;
    if (!length($unbracetest)) {
	$unbraced = 1;
    }

    print("Point 2\n") if ($hangDebug);
    my $prepart_tailparen=0;
    my $prepart_tailparen_endonly=0;
    my $isFuncPtr = 0;
    my $isTemplateFunc = 0;
    my $is_typedef = 0;
    my $newpre = "";
    my $typedef_or_function_name = "";
    my $mode = 0;
    my $prekeywords;
    my @newwords = ();
    my @namewords = ();
    if ($pascal) {
	foreach my $word (@words) {
		if ($word eq "=" || $word eq ";") {
			$mode = 1;
		}
		if ($mode) {
			push(@newwords, $word);
		} else {
			push(@namewords, $word);
		}
	}
	$typedef_or_function_name = pop(@namewords);
	while ($typedef_or_function_name !~ /\w/) {
		$typedef_or_function_name = pop(@namewords);
	}
	$typedef_or_function_name =~ s/^\s*//s;
	$typedef_or_function_name =~ s/\s*$//s;
	$typedef_or_function_name =~ s/\s+/ /s;
	foreach my $word (@namewords) {
		$prekeywords .= $word;
	}
	$prekeywords =~ s/^\s*//s;
	$prekeywords =~ s/\s*$//s;
	$prekeywords =~ s/\s+/ /s;
	@words = @newwords;
    } elsif ($prebracespart =~ /^\s*typedef\s+/s ) {
	$is_typedef = 1;
	if ($unbraced) {
		while ($typedef_or_function_name !~ /\w/ && scalar(@words)) {
			$typedef_or_function_name = pop(@words) . $typedef_or_function_name;
		}
		print "TDOFN [point 1] $typedef_or_function_name\n" if ($preDebug);
	} elsif ($prebracespart =~ s/^(.*?)\((.*)\)\s*$/$1/s) {
		$typedef_or_function_name = $2;
		@words = split(/(\W)/s, $prebracespart);
		$isFuncPtr = 1;
		$prepart_tailparen = 1;
		print "TDOFN [point 2] $typedef_or_function_name\n" if ($preDebug);
	} else {
		# It's something like a typedef struct or enum, where the
		# name comes at the end.
		$typedef_or_function_name = "";
		print "TDOFN [point 3] $typedef_or_function_name\n" if ($preDebug);
	}
    } else {
	while ($typedef_or_function_name !~ /\S/ && scalar(@words)) {
		$typedef_or_function_name = pop(@words) . $typedef_or_function_name;
	}
	print "TDOFN [point 4] $typedef_or_function_name\n" if ($preDebug);
	if ($typedef_or_function_name =~ s/\)\s*$//s) {
		while (scalar(@words) &&
		       $typedef_or_function_name !~ /\w/) {
			    $typedef_or_function_name = pop(@words) . $typedef_or_function_name;
		}
		# if ($typedef_or_function_name !~ s/^\s*\(//s) {
			# my $prev = pop(@words);
			# $prev =~ s/\(\s*$//;
			# push(@words, $prev);
		# }
		$isFuncPtr = 1;
		$prepart_tailparen = 1;
		$prepart_tailparen_endonly = 1;
		print "TDOFN [point 5] $typedef_or_function_name\n" if ($preDebug);
	} elsif ($typedef_or_function_name =~ /\s*>\s*/) {
		$isTemplateFunc = 1;
		my $continue = 1;
		while ($continue) {
		    while ($typedef_or_function_name !~ /^\s*</ && scalar(@words)) {
			$typedef_or_function_name = pop(@words) . $typedef_or_function_name;
		    }
		    my $temp = "";
		    while ($temp !~ /\W/ && $temp !~ />/ && scalar(@words)) {
			$temp = pop(@words) . $temp;
		    }
		    $typedef_or_function_name = $temp . $typedef_or_function_name;
		    if ($temp !~ /^\s*>/) { $continue = 0; }
		}
		# my $namespace = "";
		# if ($typedef_or_function_name =~ s/^(\s+)//s) {
			# $namespace = $1;
		# }
		# push(@words, $namespace);
		print "TDOFN [point 6] $typedef_or_function_name\n" if ($preDebug);
	}
    }

    print("NAME: \"$typedef_or_function_name\"\n") if ($localDebug);
    print("Point 3\n") if ($hangDebug);

    my $first = 1;
    my $lastkey;
    foreach my $word (@words) {
	if (!length($word)) { next; }
	if ($word =~ /\s/) { $newpre .= $word ; next; }
	if ($word =~ /\W/ && $word !~ /[\(\)\{\}]/) { $newpre .= $word ; next; }
# print "WORD IS \"$word\"\n";
	my $iskeyword = 0;
	foreach my $keyword (@keywords) {
		if ($case_sensitive) {
			if ($word eq $keyword) { $iskeyword = 1; last; }
		} else {
			if ($word =~ /^\s*$keyword\s*$/i) { $iskeyword = 1; last; }
		}
		# else {
			# print "not keyword $word != $keyword\n";
		# }
	}
	if ($word eq "") {
		$newpre .= " ";
	} elsif ($word eq "}" || $word eq ")") {
		$newpre .= $word;
	} else {
	    # if ($first) { $first = 0; } else { $newpre .= " "; }
	    if ($iskeyword) {
		$newpre .= "<font class=\"keyword\">$word</font>";
		$lastkey = $word;
	    } else {
		my $starend = "";
		if ($word =~ s/(\*+\s*)$//) {
			$starend = $1;
		}
		my $ref = $self->genRef($lastkey, $word, "<font class=\"type\">$word</font>");
		$newpre .= $ref; # "<!-- a logicalPath=\"$ref\" --><font class=\"type\">$word</font><!-- /a -->";
		if (length($starend)) {
			# warn("$starend");
			# @@@ IS THIS EVER NONEMPTY?
			if ($starcolor) {
				$newpre .= "<font class=\"type\">$starend</font>";
			} else {
				$newpre .= "$starend";
			}
		}
	    }
	}
    }
    print "NEWPRE [point 1] IS $newpre\n" if ($preDebug);
    # $newpre =~ s/^ //;
    # if (!$first) { $newpre .= " "; }
    if ($prepart_tailparen && !$prepart_tailparen_endonly) { $newpre .= "("; }
    if ($functionBlock) {
        if ($typedef_or_function_name =~ /^(\s*)(\*+)(.*?)$/) {
	    my $initspace = $1;
            my $starpart = $2;
            my $rest = $3;
	    # star part of names in function pointers, star part of
	    # names of simple typedefs
	    if ($starcolor) {
		if ($is_typedef  && !$isFuncPtr && !$isTemplateFunc) {
           		$newpre .= "$initspace<font class=\"type\">$starpart</font>";
		} else {
           		$newpre .= "$initspace<font class=\"function\">$starpart</font>";
		}
	    } else {
           	$newpre .= "$initspace$starpart";
	    }
            $typedef_or_function_name = $rest;
        }
    }
    print "NEWPRE [point 2] IS $newpre\n" if ($preDebug);
    print "TDOFN \"$typedef_or_function_name\"\n" if ($preDebug);
    if (length($typedef_or_function_name)) {
	my $semi = "";
	if ($typedef_or_function_name =~ s/;\s*$//s) { $semi = ";"; };
	my $tdprespace = "";
	if ($typedef_or_function_name =~ s/^(\s+)//s) { $tdprespace = $1; }
	my $tdprestar = "";
	if (!$starcolor) {
		if ($typedef_or_function_name =~ s/^(\*+)//s) {
			$tdprestar = $1;
		}
	}
	if ($semi eq "" && $typedef_or_function_name =~ s/(\s+)$//s) {
		$semi = $1;
	}
	if ($pascal) {
	    $newpre = "<font class=\"keyword\">$prekeywords</font> $tdprestar<font class=\"function\">$typedef_or_function_name</font> $newpre";
	} elsif ($is_typedef && !$isFuncPtr && !$isTemplateFunc) {
	    $newpre .= "$tdprespace$tdprestar<font class=\"type\">$typedef_or_function_name</font>$semi";
	} else {
	    $newpre .= "$tdprestar<font class=\"function\">$typedef_or_function_name</font>$semi";
	}
    }
    if ($prepart_tailparen) { $newpre .= ")"; }
    print "NEWPRE [point 3] IS $newpre\n" if ($preDebug);

# warn("BEFORE HERE\n");
# colorize the in-braces/in-parentheses part

    my $single; my $param_or_var;
    my $newin = "";
    my $split = 0;
    if ($lang eq "pascal" || ($lang eq "C" && $sublang eq "MIG")) {
	print "Note: not coloring contents of pascal records for now.\n";
	# @@@ ADD pascal/mig colorizer routine here @@@
	$newin = $inbracespart;
    } else {

    if ($functionBlock) {
        if ($declaration =~ /;$/s) {
            # we're a function prototype, so a single word is
            # the name of a function parameter
            $single = "param";
        } else {
            # we're either a #define macro or a function
            # declaration.  A single word is the name of a
            # type.
            $single = "type";
        }
    } else {
# print "CONFUSED: \"$declaration\"\n";
	# this is probably bordering on illegal, but we'll call
	# it a parameter anyway.
	# $single = "param";
	$single = "var";
    }
    if ($functionBlock) {
	$param_or_var = "param";
    } else {
	$param_or_var = "var";
    }
    print "splitchar $splitchar\n" if ($localDebug);
    my @params = split(/$splitchar/smg, $inbracespart);
print "IBP: $inbracespart\n" if ($localDebug);

    my $lastsplit = "";
    my $recurseBlock = "";
    my $firstparam = 1;

    if (((length($inbracespart) + length($prebracespart)) > $HeaderDoc::maxDecLen)) { $split = 1; }

    my $braced = 0;
    if ($startParamChar eq "{") {
	$split = 1;
	$braced = 1;
    }

    my $recurseType = "";
    foreach my $oldparam (@params) {
# print "newin is NOW \"$newin\"\n";
      if (!length($oldparam)) { next; }
      print "OLDPARAM IS \"$oldparam\"\n" if ($localDebug);
      my $param = $oldparam;
      # $param =~ s/^\s*//s;
      # my $leadspace = "";
      # if (($firstparam && !($braced || (length($param) + length($prebracespart)) > $HeaderDoc::maxDecLen))) {
	      # $firstparam = 0;
      # } else {
	# if ($oldparam eq "\n") { $leadspace .= "\n"; }
	# elsif ($split && ($param !~ /$splitchar/)) { $leadspace .= "\n    "; }
      # }
      # $param = $leadspace . $param;
      my $nospaceparam = $param;
      $nospaceparam =~ s/^\s+//;
      if (!length($nospaceparam)) { $nospaceparam = $param; }

      print "param \"$param\"\n" if ($localDebug);

      if ($nospaceparam =~ /$splitchar/) {
	print "set lastsplit to '$param'\n" if ($localDebug);
	if ($recurseBlock) {
	    print "RCB: $recurseBlock\n" if ($localDebug);
	    $recurseBlock .= "$param";
	    if (!($param eq "\n")) {
		print "leaving RCB\n" if ($localDebug);
	        my $recurseResult = "";
	        if ($recurseBlock =~ /\}/) {
		    $recurseResult = $self->complexTypeColor($recurseBlock);
	        } else {
		    $recurseResult = $self->functionColor($recurseBlock);
		    if ((length($recurseBlock) <= $HeaderDoc::maxDecLen)) {
			$recurseResult =~ s/\n//sg;
			$recurseResult .= "\n";
		    }
		}

		print "recurseResult:\n$recurseResult\nENDrecurseResult\n" if ($localDebug);

		$recurseResult =~ s/<br>/\n/smg;

		$recurseResult =~ s/<tt>//smg;
		$recurseResult =~ s/<\/tt>//smg;
		$recurseResult =~ s/<pre>//smg;
		$recurseResult =~ s/<\/pre>//smg;

		my $oldresult = $recurseResult;

		my $newResult = ""; my $first = 1; my $endspace = "";
		my @resultArray = split(/(\n)/smg, $recurseResult);
		foreach my $resultLine (@resultArray) {
		    if ($resultLine eq "\n") {
			$newResult .= $resultLine;
		    } else {
			# $newResult .= "&nbsp;";
			# if ($resultLine =~ /\);$/) {
			    # $newResult .= "&nbsp;&nbsp;";
			# } elsif ($first) {
			    # $first = 0;
			    # $newResult .= "&nbsp;";
			# }
			$resultLine =~ s/^&nbsp;/ /g;
			if ($first) {
				my $scratch = $resultLine;
				$first = 0;
				while ($scratch =~ s/^\s//) {
					$endspace .= " ";
				}
			} elsif ($resultLine =~ /\);$/ || $resultLine =~ /\}\s*\S*\s*;$/) {
				$resultLine = "$endspace$resultLine";
			}
			# print "raw resultLine: $resultLine\n" if ($localDebug);
			# print "space resultLine: $resultLine\n" if ($localDebug);
			print "resultLine: $resultLine\n" if ($localDebug);
			$newResult .= $resultLine;
		    } # end else (line ! eq \n)
		} # end foreach
		$newResult =~ s/<br>/\n/g;

		print "newResult was $newResult\n" if ($localDebug);

		# $newin .= "<P>$recurseResult</P>";
		$newin .= $newResult;
		$recurseBlock = "";
	    } # end if (!($param eq "\n")) {
	    $lastsplit = $param; next;
	} else {
	    # not $recurseBlock
	    $lastsplit = $param; $newin .= "$param"; next;
	}
      } else {
	# param !~ /$splitchar/
	if ($recurseBlock) {
	    $recurseBlock .= $param; next;
	} else {
	    print "text.\n" if ($localDebug);
	}
      }

      if ($lastsplit eq ";" || ($lastsplit eq "," && !$functionBlock)) {
	$newin .= $param;
	print "skip\n" if ($localDebug);
	next;
      }

      $param =~ s/\s$//g;

      if ($param =~ /^.*?\(.*\)\s*\(.*/sm) {
          print "Nested Callback Found\n" if ($localDebug);
          $recurseBlock = $param;
          $recurseType = "func";
	  next;
      }
      if ($param =~ /\(/s && $lang ne "pascal") {
          print "Nested Function Declaration Found\n" if ($localDebug);
          $recurseBlock = $param;
          $recurseType = "func";
	  next;
      }
      my $leadingComment = "";
          if (length($ilc) && $param =~ /^\s*$ilcquot/) {
		$leadingComment = $param;
		$param = "";
      } elsif (length($soc) && length($eoc)) {
	    while ($param =~ s/^(\s*$socquot.*?$eocquot\s*)//) { # @@@ COMMENT
		$leadingComment .= $1;
	    }
      }
      # print "LC = $leadingComment\n";
      # $newin .= "<font class=\"comment\">$leadingComment</font>";
      # Don't wrap it.  This will happen later....
      $newin .= $leadingComment;

      my @words = split(/(\s)/, $param);
      my $paramname;

      my $value;
      if ($param =~ /=/) {
	$value = $param;
	$value =~ s/.*=//;
	$param =~ s/=.*//;
	@words = split(/(\s)/,$param);
	$paramname = pop(@words);
      } else {
	$value = "";
	while ($paramname !~ /\S/ && scalar(@words)) { $paramname = pop(@words); }
	# $paramname =~ s/^\s*//sg;
	# if ($paramname =~ s/^(\*+)//) {
		# my $starpart = $1;
		# push(@words, $starpart);
	# }
      }
      my $first = 1;
      my $lastkey = "";
      my $pascalnamepending = 0;
      if ($lang eq "pascal") { $pascalnamepending = 1; }
      foreach my $word (@words) {
# print "WORD: $word\nPNP: $pascalnamepending\n";
	# print "WORD____X\n";
	# print "$word"."X\n";
	my $iskeyword = 0;
	foreach my $keyword (@keywords) {
		if ($word eq $keyword) { $iskeyword = 1; last; }
		# else {
			# print "not keyword $word != $keyword\n";
		# }
	}
	if ($word =~ /\s/) { $newin .= $word; next; }
	elsif ($word eq "") {
		next;
		# if ($first) { $first = 0; } else { $newin .= " "; }
	} elsif ($pascalnamepending) {
		$newin .= "<font class=\"$param_or_var\">$word</font>";
		next;
	} else {
	    # if ($first) { $first = 0; } else { $newin .= " "; }
	    if ($iskeyword) {
		$newin .= "<font class=\"keyword\">$word</font>";
		$lastkey = $word;
            } elsif (($word =~ /^\s*}/) || ($word =~ /^\s*\)/)) {
		$newin .= $word;
	    } else {
		my $starend = "";
		if ($word =~ s/(\*+\s*)$//) {
			$starend = $1;
		}
		my $ref = $self->genRef($lastkey, $word, "<font class=\"type\">$word</font>");
		# $newin .= "<font class=\"type\">$word</font>";
		$newin .= $ref; # "<!-- a logicalPath=\"$ref\" --><font class=\"type\">$word</font><!-- /a -->";
		if (length($starend)) {
			# @@@ IS THIS EVER NONEMPTY?
			if ($starcolor) {
				$newin .= "<font class=\"type\">$starend</font>";
			} else {
				$newin .= "$starend";
			}
		}
	    }
	}
      }
      # if (!$first) { $newin .= " "; }
# print "newin is NOW - B \"$newin\"\n";
      if ($paramname =~ /^(\*+)(.*?)$/) {
       my $starpart = $1;
       my $rest = $2;
       if ($first) {
           if ($starpart =~ /^\s*}/ || $starpart =~ /^\s\)/) {
               $newin .= $starpart;
           } else {
		# star before variable names inside structures
		# and star before parameter names in functions.

		# wrong for types
		if ($starcolor) {
			if ($single eq "type") {
			    $newin .= "<font class=\"type\">$starpart</font>";
			} else {
			    $newin .= "<font class=\"$single\">$starpart</font>";
			}
		} else {
			$newin .= "$starpart";
		}
           }
       } else {
            # $newin .= "<font class=\"type\">$starpart</font>";
	    # @@@ IS THIS EVER NONEMPTY?
	    if ($starcolor) {
		$newin .= "<font class=\"type\">$starpart</font>";
	    } else {
		$newin .= "$starpart";
	    }
       }
       $paramname = $rest;
      }
      $newin .= "<font class=\"$param_or_var\">$paramname</font>";
      if (length($value)) {
	print "VALUE is $value\n" if ($localDebug);
	my $tail = $value;
	if ($tail =~ s/^\s*(-|)(\d+)//s) {
	    # $value =~ s/\s*//g;
	    $value = "$1$2";
	    if ($tail =~ s/^x//g) {
		$tail =~ s/((\d|a|b|c|d|e|f)+)//is;
		$value .= "x$1";
	    }
	    if ($tail =~ s/\.//g) {
		$tail =~ s/(\d+)//s;
		$value .= ".$1";
	    }
	    if ($tail =~ s/^(f|ul|u|l)//is) {
		$value .= "$1";
	    }
	    $newin .= "= <font class=\"number\">$value</font>$tail";
	} else {
	    my $parsed_quotes = $self->stringAndCharColor($value);
	    $newin .= "= $parsed_quotes";
	}
      }
    }
    $newin =~ s/^;//;
    # $newin =~ s/^ //m; # DO NOT CHANGE TO \s!
    $newin =~ s/\n+$/\n/smg;
    }

    # conditionally process the postbraces material
    my $newpost = "";

   if (($is_typedef) || (($lang eq "Csource") && ($postbracespart !~ /^\s*;\s*$/smg))) {
      # It could potentially include K&R C declarations, or could be the
      # actual name of a "typedef [struct|enum] {...} name;" declaration.

	if ($is_typedef) { $postbracespart =~ s/^\s*//g; }

        my @params = split(/(;)/, $postbracespart);

        my $firstparam = 1;
	print "parms from \"$postbracespart\"\n" if ($parmDebug);
	my $lastkey = "";
        foreach my $param (@params) {
print "TAILPARM: \"$param\"\n" if ($parmDebug);
	  if ($param =~ /^\s*;\s*$/) {
              $firstparam = 0;
              $newpost .= ";"; # $param;
	  } elsif ($is_typedef) {
              if ($firstparam && length($param)) {
                  $firstparam = 0;
                  $newpost .= " <font class=\"var\">$param</font>";
              } else {
                  $newpost .= "$param";
              }
          } else {
	      $param =~ s/\n//g;
              my @words = split(/\s/, $param);
              my $paramname = pop(@words);

	      # print "param \"$param\"\n";

              if (!$firstparam) { $newpost .= "\n"; }
	      my $first = 1;
              foreach my $word (@words) {
	        my $iskeyword = 0;
	        foreach my $keyword (@keywords) {
		    if ($word eq $keyword) { $iskeyword = 1; last; }
		    # else {
			    # print "not keyword $word != $keyword\n";
		    # }
	        }
	        if ($word eq "" && !$first) {
		    $newpost .= " ";
	        } else {
		    if ($first) { $first = 0; } else { $newpost .= " "; }
		    if ($iskeyword) {
		        $newpost .= "<font class=\"keyword\">$word</font>";
			$lastkey = $word;
		    } else {
			my $starend = "";
			if ($word =~ s/(\*+\s*)$//) {
				$starend = $1;
			}
			my $ref = $self->genRef($lastkey, $word, "<font class=\"type\">$word</font>");

		        # $newpost .= "<font class=\"type\">$word</font>";
			$newpost .= $ref; # "<!-- a logicalPath=\"$ref\" --><font class=\"type\">$word</font><!-- /a -->";
			if (length($starend)) {
				# @@@ IS THIS EVER NONEMPTY?
				if ($starcolor) {
					$newpost .= "<font class=\"type\">$starend</font>";
				} else {
					$newpost .= "$starend";
				}
			}
		    }
	        }
              }
	      if (!$first) { $newpost .= " "; }
              $newpost .= "<font class=\"$param_or_var\">$paramname</font>";
          }
	}
	print "EndParms\n" if ($parmDebug);
	# if ($functionBlock) {
		# $newpost =~ s/^,\n//;
	# } else {
        	# $newpost =~ s/^;\n//;
	# }
	# $newpost =~ s/^ //m; # DO NOT CHANGE TO \s!
	# print "old was $postbracespart\n";
	# print "newpost is $newpost\n";
    } else {
	$newpost = $postbracespart;
	# print "$postbracespart\n";
    }

# print "newpre $newpre\n"; print "pre: $prebracespart\n";

    if ($is_typedef && $deFunTail) { # @@@
	if ($deFunTail =~ s/(.*?);//g) {
		my $typedef_name = "<font class=\"var\">$1</font>;";
		$deFunTail = "$typedef_name$deFunTail";
	}
    }

# print "NP: \"$newpost\"\n";

    my $newdeclaration;
    my $optnewline = "";
    if ($split) { $optnewline = "\n"; }
    if ($parenthesized) {
	$newin =~ s/\n*$//smg;
	if ($deFun && $functionBlock) {
	    $newdeclaration = "$initspace$newpre$startParamChar$newin$optnewline$endParamChar$newpost";
        } else {
            $newdeclaration = "$initspace$newpre$startParamChar$newin$optnewline$endParamChar$newpost";
        }
    } else {
	$newdeclaration = "$initspace$newpre";
    }
# print "NEWDEC=$newdeclaration\n";

    if ($functionBlock) {
        if ($deFun) {
            $newdeclaration .= "{ $deFunBody } $deFunTail";
        }
        if ($parenReturnType) {

	    my @parenRetWords = split(/\s/, $parenReturnType);

	    my $typepart = "";
	    my $namepart = pop(@parenRetWords);
	    foreach my $prw (@parenRetWords) {
		$typepart .= " $prw";
	    }
	    $typepart =~ s/^ //s;

	    # print "SPLITS: $parenReturnType A $typepart B $namepart END\n";

	    my $fonttypepart = "";

	    my $starend = "";
	    if ($typepart =~ s/(\*+\s*)$//) {
		$starend = $1;
	    }

	    my $ref = "";
	    if (length($typepart)) {
		$fonttypepart = "<font class=\"type\">$typepart</font>";
		$ref = $self->genRef($typepart, $namepart, $fonttypepart); # @@@ FIXME
	    }
	    if (length($starend)) {
		# @@@ IS THIS EVER NONEMPTY?
		if ($starcolor) {
			$ref .= "<font class=\"type\">$starend</font>";
		} else {
			$ref .= "$starend";
		}
	    }

            my $parendeclaration = "($ref) ".$newdeclaration;

            $newdeclaration = $parendeclaration;
# print "PRT: $parenReturnType\n";
        }
        if ($objCPrefix) {
            my $prefixdeclaration = "<font class=\"keyword\">$objCPrefix</font> ".$newdeclaration;
            $newdeclaration = $prefixdeclaration;
# print "objCPrefix: $prefixdeclaration\n";
        }
    }

# print "newpre: $newpre\n";
# print "newin: $newin\n";
# print "newpost: $newpost\n";
    # $newdeclaration =~ s/^ /&nbsp;/mig;
    # $newdeclaration =~ s/&nbsp; /&nbsp;/mig;
    # $newdeclaration =~ s/\n/<br>/smig;

    # print "old dec was \"$declaration\"\n";

print "BEGIN:\n$newdeclaration\nEND\n" if ($localDebug || $parmDebug);
print "is_typedef: $is_typedef\n" if ($parmDebug);

    $newdeclaration .= $tailcomment;

    if ($tt) {
	return "<tt>$newdeclaration</tt>";
    } elsif ($pre) {
	return "<pre>$newdeclaration</pre>";
    } else {
	return $newdeclaration;
    }
}


# /*! @function functionColor
#     @abstract parse function declaration, adding coloration
#  */
sub functionColor
{
    my $self = shift;
    my $declaration = shift;
    my $lang = $self->lang();
    my $sublang = $self->sublang();
    my $objC = 0;
    my $class = ref($self) || $self;
    my $rawdeclaration = $self->declaration();

# print "functionColor:\n$declaration\nendfunctionColor\n";

    if ($class eq "HeaderDoc::PDefine" || $rawdeclaration =~ /^\s*#define\s+/s) {
	return $self->defineColor($declaration);
    }

    if ($lang eq "C") {
	SWITCH: {
	    ($sublang =~ "^occ") && do { $objC=1; last SWITCH; }; #occ, occCat
	    ($sublang eq "intf") && do { $objC=1; last SWITCH; };
	}
    }

    if ($objC) {
	return $self->objCFunctionColor($declaration, $lang);
    } else {
	return $self->CFunctionColor($declaration, $lang);
    }

}

sub objCleadcolor
{
    my $self = shift;
    my $decl = shift;

    $decl =~ /(.*)\((.*)\)/;
    $decl = $1;
    my $type = $2;

    $type =~ s/\s*$//;

    my $tailstars = "";
    if ($type =~ s/\s*(\*+)$//) {
	$tailstars = " <font class=\"type\">$1</font>";
    }

    my $ref = $self->genRef("", $type, "<font class=\"type\">$type</font>");
    $decl .= "($ref$tailstars)";

    return $decl;
}

sub objCFunctionColor
{
    my $self = shift;
    my $declaration = shift;
    my $lang = shift;
    my $localDebug = 0;
    my $parseDebug = 0;

# print "objCFunctionColor: DEC $declaration\n";

    if ($declaration !~ s/^\s*[+-]\s*//s) {
	return $self->CFunctionColor($declaration);
    }

    my $leadin = $1;

    my $nameState = 0;
    my $colonparenState = 1;
    my $argtypeState = 2;
    my $parenState = 3;
    my $argnameState = 4;
    my $retvalState = 5;

    my $state = $nameState;
    my $nextstate = $nameState;
    my $colordec = "";
    my $name = "";
    my $curarg = "";
    my $position = 0;

    my $namestyle       = "<font class=\"function\"><b>";
    my $endnamestyle    = "</b></font>";
    my $argtypestyle    = "<font class=\"type\">";
    my $endargtypestyle = "</font>";
    my $argnamestyle    = "<font class=\"param\">";
    my $endargnamestyle = "</font>";
    my $retvalstyle     = "<font class=\"type\">";
    my $endretvalstyle  = "</font>";
    my $curargtype = "";

    $self->parsedParameters(());

    if ($declaration =~ s/^\s*\(//s) {
	# print "RETVALSTATE\n";
	$state = $retvalState;
	$nextstate = $retvalState;
	$colordec .= "("
    }

# print "DECHERE IS $declaration\n";
    
    foreach my $token (split(/(\W)/, $declaration)) {
	# print "BTOKEN: $token\n";
	if (!length($token)) { next; }
	SWITCH: {
		($token =~ /\s/) && do {
				# print "SPACE\n" if ($parseDebug);
				if ($state == $argnameState &&
				    length($curarg)) {
					$state = $nameState;
					print "OBJCMETHODSTATE->nameState\n" if ($localDebug);

					my $param = HeaderDoc::MinorAPIElement->new();
					$param->outputformat($self->outputformat);
					$param->name($curarg);
					$param->position($position++);
					$param->type($curargtype);
					$self->addParsedParameter($param);

					$curargtype = "";
					$curarg = "";
				}
				last SWITCH;
			};
		($token =~ /:/) && do {
				print "COLON\n" if ($parseDebug);
				$nextstate = $colonparenState;
				print "OBJCMETHODNEXTSTATE->colonparenState\n" if ($localDebug);
				last SWITCH;
			};
		($token =~ /\(/) && do {
				print "OPENPAREN\n" if ($parseDebug);
				$state = $parenState;
				$nextstate = $argtypeState;
				print "OBJCMETHODSTATE->parenState, OBJCMETHODNEXTSTATE->argtypeState\n" if ($localDebug);
				last SWITCH;
			};
		($token =~ /\)/) && do {
				print "CLOSEPAREN\n" if ($parseDebug);
				if ($state == $retvalState) {
					$nextstate = $nameState;
					print "OBJCMETHODSTATE->parenState, OBJCMETHODNEXTSTATE->nameState\n" if ($localDebug);
				} else {
					$nextstate = $argnameState;
					print "OBJCMETHODSTATE->argnameState\n" if ($localDebug);
				}
				$state = $parenState;
				last SWITCH;
			};
		($token =~ /\w/) && do {
				print "WORD\n" if ($parseDebug);
				if ($state == $argnameState) {
					$curarg .= $token;
				}
				last SWITCH;
			};
		($token =~ /[;,*<>]/) && do {
				# We really don't care about these.
				print "NOISE\n" if ($parseDebug);
				last SWITCH;
			};
		{
			print "UNKNOWN TOKEN \"$token\"\n" if ($parseDebug);
		}
	}
# print "st01: $state\n";
	if ($state == $nameState) {
		$name .= $token;
	}

# print "st02: $state\n";
	# do formatting here based on $state
	if ($token =~ /[\s:;,]/) {
		$colordec .= $token;
		next;
	}
# print "TOKEN : $token, STATE : $state\n";
	if (0) { # $iskeyword($token))
		# For now, do nothing here, but this needs to be done.
	} else {
	    SWITCH: {
		($state == my $nameState) && do {
			$colordec .= "$namestyle$token$endnamestyle";
			last SWITCH;
			};
		($state == $colonparenState) && do {
			$colordec .= "$token";
			last SWITCH;
			};
		($state == $argtypeState) && do {
			$colordec .= "$argtypestyle$token$endargtypestyle";
			$curargtype .= $token;
			last SWITCH;
			};
		($state == $parenState) && do {
			$colordec .= "$token";
			last SWITCH;
			};
		($state == $argnameState) && do {
			$colordec .= "$argnamestyle$token$endargnamestyle";
			last SWITCH;
			};
		($state == $retvalState) && do {
			$colordec .= "$retvalstyle$token$endretvalstyle";
			last SWITCH;
			};
		{
			warn "objCFunctionColor: UNKNOWN STATE!\n";
		}
	    }
	}

	
# print "st03: $state\n";
	$state = $nextstate;
# print "st04: $state\n";
    }


    return $colordec;
}

sub old_objCFunctionColor
{
    my $self = shift;
    my $declaration = shift;
    my $lang = shift;
    my $orig_declaration = $declaration;
    my $filename = $HeaderDoc::headerObject->filename();
    my $localDebug = 0;
    my $compareDebug = 0;

    print "RAWDEC: $declaration\n" if ($localDebug);

    $declaration =~ s/<tt>//smg;
    $declaration =~ s/<\/tt>//smg;
    $declaration =~ s/<pre>//smg;
    $declaration =~ s/<\/pre>//smg;

    print "DEC: $declaration\n" if ($localDebug);

    $declaration =~ s/\s*//s;
    my $leadin = "";
    if ($declaration =~ /([-+]?\s*\(.*?\))(.*)/s) {
	$leadin = $1;
	$declaration = $2;
    }

    my @parts = split(/([:\n])/s, $declaration);
    my @newparts = ();
    my $colordec = "";
    foreach my $part (@parts) {
	if ($part eq ":") {
		push(@newparts, $part);
		print "pushed $part\n" if ($localDebug);
	} elsif ($part =~ /^\s*\(/) {
		my $colon = pop(@newparts);
		my $lastpart = "";
		if ($colon eq ":") { $lastpart = pop(@newparts); }
		my $newpart = "$lastpart$colon$part";
		push(@newparts, $newpart);
		print "pushed $newpart\n" if ($localDebug);
	} else {
		push(@newparts, $part);
		print "pushed $part\n" if ($localDebug);
	}
    }

    foreach my $part (@newparts) {
	if ($part eq ":") {
		$colordec .= $part;
	} else {
		my $nl = 0;
		# $part =~ s/<br>/\n/smg;
		# $part =~ s/\n$//sg;
		# $part =~ s/;\s*$//; # HACK: s/;.*?$//
		if ($part =~ /^\n/) { $nl = 1; }
		if ($part !~ /;$/) { $part .= ";"; }
		$colordec .= $self->CFunctionColor($part, $lang);
		$colordec =~ s/;(\s*)$/$1/smg; # HACK: s/;.*?$//
		if ($nl) { $colordec = "\n$colordec"; }
		print "COMPARE:$part\nTO:$colordec\nEND\n" if ($compareDebug);
	}
	print "PART WAS $part\n";
    }
    # $colordec .= ";";
    if (length($leadin)) {
	my $colorlead = $self->objCleadcolor($leadin);
	$colordec = "$colorlead$colordec";
    }

    my $newcolordec = "";
if (1) {
    $newcolordec = $colordec;
} else {
    my $tempdec = $self->declaration();
    $tempdec =~ s/\n//sg;
    if ((length($tempdec) > $HeaderDoc::maxDecLen)) {
	# print "length is " . length($tempdec) . ".\n";
        my @lines = split(/\n/, $colordec);;
        my $first = 1;
        foreach my $line (@lines) {
	    my $templine = $line;
	    if ($first) {
	        $templine =~ s/\s*//g;
	        if (length($templine)) {
		    $first = 0;
	        }
	    } else {
	        $line = "&nbsp;&nbsp;&nbsp;$line";
	    }
	    $newcolordec .= "$line\n";
        }
    } else {
	$newcolordec = $colordec;
	$newcolordec =~ s/\n//sg;
    }
}

    # my $shortret = $self->blockColor($declaration, 1);
    # return $shortret;
    return "<pre>$newcolordec</pre>";
}

# /*! @function CFunctionColor
#     @param self class
#     @param declaration the declaration to color
#  */
sub CFunctionColor
{
    my $self = shift;
    my $declaration = shift;
    my $orig_declaration = $declaration;
    my $localDebug = 0;
    my $lang = $self->lang();
    my $sublang = $self->sublang();
    my $filename = $HeaderDoc::headerObject->filename();

    print "in CFunctionColor\n" if $localDebug;
    my $shortret = $self->blockColor($declaration, 1);
    print "leaving CFunctionColor\n" if $localDebug;
    return $shortret;
}

#/*! @function stringAndCharColor  
#    @abstract does coloring of strings and characters.
# */
sub stringAndCharColor
{
    my $self = shift;
    my $declaration = shift;

    # print "SACC: $declaration\n";

    my $newdec = $self->dataColor($declaration, 1);

    return $newdec;
}


#/*! @function commentColor  
#    @abstract does coloring of comments, etc.
# */
sub commentColor
{
    my $self = shift;
    my $declaration = shift;

    my $newdec = $self->dataColor($declaration, 0);

    return $newdec;
}

#/*! @function dataColor  
#    @abstract does coloring of data, comments, etc.
# */
sub dataColor
{
    my $self = shift;
    my $declaration = shift;
    my $parse_strings = shift;
    my $localDebug = 0;

print "input declaration: $declaration\n" if ($localDebug);
# return $declaration;                
    $declaration =~ s/<br>/\n/smg;

    my $inComment = 1;
    my $inLineComment = 2;
    my $inChar = 3;
    my $inString = 4;
    my $inMacro = 5;
    my $state = -1;
    my $lang = $self->lang();
    my $sublang = $self->sublang();

    my ($sotemplate, $eotemplate, $soc, $eoc, $ilc, $sofunction,
	$soprocedure, $sopreproc, $lbrace, $rbrace, $structname,
	$structisbrace) = parseTokens($lang, $sublang);

    my $socquot = quote($soc);
    my $eocquot = quote($eoc);
    my $ilcquot = quote($ilc);

    my @parts;

    # if ($parse_strings) {
	# print "SOCQUOTE: \"$socquot\"\n";
	# print "EOCQUOTE: \"$eocquot\"\n";
	# print "ILCQUOTE: \"$ilcquot\"\n";

	my $searchstring = "";
	if (length($socquot)) { $searchstring .= "|$socquot"; }
	if (length($eocquot)) { $searchstring .= "|$eocquot"; }
	if (length($ilcquot)) { $searchstring .= "|$ilcquot"; }
	$searchstring =~ s/^\|//;
	if (length($searchstring)) {
        	@parts=split(/($searchstring|'|"|\n)/, $declaration); # @@@ COMMENT
	} else {
        	@parts=split(/('|"|\n)/, $declaration); # @@@ COMMENT
	}
        # @parts=split(/(\/\*|\*\/|\/\/|'|"|\n)/, $declaration); # @@@ COMMENT
	# foreach my $part (@parts) { 
		# print "PART: $part\n";
	# }
    # } else {
        # @parts=split(/(\/\*|\*\/|\/\/|^#|\n)/, $declaration);
    # }
    my $newdec = ""; my $starpart = 0;
    foreach my $part (@parts) {
        print "State $state\n" if ($localDebug);
	print "PART IS \"$part\"\n" if ($localDebug);
        if ($state == -1) { $state = 0; $newdec .= $part; next; }

        SWITCH: {
                ($part eq "$soc") && do {
                        print "SoC\n" if ($localDebug);
                        if ($state != $inLineComment &&
                            $state != $inString) {
                                $state = $inComment;
                                $newdec .= "<font class=\"comment\">";
                        }
                        $newdec .= $part; last SWITCH;
                    };      
                ($part eq "$eoc") && do {
                        print "EoC\n" if ($localDebug);
                        $newdec .= $part;
                        if ($state == $inComment) {
                                $state = 0;
                                $newdec .= "</font>";
                        }
                        last SWITCH;
                    };
                ($part eq "$ilc") && do {
                        print "SoSLC\n" if ($localDebug);
                        # start of comment?
                        if ($state != $inComment && $state != $inString) {
                        	print "REAL SoSLC\n" if ($localDebug);
                                $state = $inLineComment;
                                $newdec .= "<font class=\"comment\">";
                        }     
                        $newdec .= $part; last SWITCH;
                    };
                ($part eq "\n") && do {
                        print "newline\n" if ($localDebug);
                        if ($state == $inLineComment) {     
                                $state = 0;
                                $newdec .= "</font>";     
                        }
                        $newdec .= $part;
			# print "NEWDEC WAS: $newdec\n";
			last SWITCH;
                    };
                ($part eq "'")  && do {
                        print "SQuo\n" if ($localDebug);
                        if ($state != $inLineComment && $state != $inComment &&
                            $state != $inString) {
                                if ($state == $inChar) {
                                        if ($newdec =~ /\\$/) {
                                                $newdec .= $part ; last SWITCH;
                                        } else {  
                                                $newdec .= $part;
                                                if ($parse_strings) {
							$newdec .= "</font>"; 
						}
                                                $state = 0;
                                                last SWITCH;
                                        }
                                } else {
                                        if ($parse_strings) {
						$newdec .= "<font class=\"char\">$part";
					} else {
						$newdec .= $part;
					}
                                        $state = $inChar;
                                        last SWITCH;
                                }
                        }
                    };   
                ($part eq "\"") && do {
                        print "DQuo\n" if ($localDebug);
                        if ($state == $inString) {
                                if ($newdec =~ /\\$/) {  
                                        $newdec .= $part; last SWITCH;
                                } else {
                                        $state = 0;
					print "out\n" if ($localDebug);
                                        $newdec .= $part;
                                        if ($parse_strings) {
						$newdec .= "</font>";
					}
                                        last SWITCH;  
                                }
                        } elsif ($state != $inComment && $state != $inLineComment) {
                                $state = $inString;
                                if ($parse_strings) {
					$newdec .= "<font class=\"string\">";
				}
                                $newdec .= $part;
                                last SWITCH;
                        }
                    };
                {     
                        # It's just text.
                        if ($state) {
				print "STATE\n" if ($localDebug);
				my $origpart = $part;
                                # $part =~ s/<font.*?>//smg;
                                # $part =~ s/<\/font.*?>//smg;
				if ($part =~ s/\*\/.*$//sg) {
					print "terminator.\n" if ($localDebug);
					$newdec .= "$part*/</font>";
					$state = 0;
					$origpart =~ s/.*?\*(<\/font>|<font class=.*?>)*\///;

					print "Start: $part\n" if ($localDebug);
					print "Remainder: $origpart\n" if ($localDebug);

					$part = $origpart;
				} else {
					print "PART: $part\n" if ($localDebug);
				}
                        }
                        print "TEXT\n" if ($localDebug);       
                        $newdec .= $part;
                }
        }
    }

    if ($state) {
	$newdec .= "</font>";
    }

    $declaration = $newdec;

    $declaration =~ s/\n/<br>/smg;      
    return $declaration;
}

sub textToXML
{
    my $self = shift;
    my $xmldec = shift;

    $xmldec =~ s/&/&amp;/sg;
    $xmldec =~ s/</&lt;/sg;
    $xmldec =~ s/>/&gt;/sg;

    return $xmldec;
}

sub declarationInHTML {
    my $self = shift;
    my $class = ref($self) || $self;
    my $localDebug = 0;
    my $lang = $self->lang();
    my $xml = 0;
    if ($self->outputformat() eq "hdxml") { $xml = 1; }

    if (@_) {
	if ($xml) {
		my $xmldec = shift;

        	$self->{DECLARATIONINHTML} = $self->textToXML($xmldec);
		return $xmldec;
	}
		
	my $declaration = shift;

	# @@@ DISABLE STYLES FOR DEBUGGING HERE @@@
	if ($HeaderDoc::use_styles && 1) {
	  my $rawdec = $declaration;
	  $rawdec =~ s/&nbsp;/ /g;
	  $rawdec =~ s/<.*?>//smg;

	  # Do not turn this on.
          my $cleanup = 0;
          if ($cleanup) {
		$rawdec =~ s/\n/ /sg;
		$rawdec =~ s/\s*\(\s*/\(/sg;
		$rawdec =~ s/\s*\)\s*/\)/sg;
		$rawdec =~ s/\s*\;\s*/\;/sg;
		$rawdec =~ s/\s*\:\s*/\:/sg;
		$rawdec =~ s/\s+/ /sg;
		$declaration = $rawdec;
	  }

	  print "rawdec was $rawdec\n/rawdec\n" if ($localDebug);
          # $self->{DECLARATION} = $rawdec;
	  SWITCH: {
		# @@@ SIMPLE TYPE?
	      ($class eq "HeaderDoc::Function" || $class eq "HeaderDoc::Method" ||
	       ($class eq "HeaderDoc::Typedef" && $lang ne "pascal" && $rawdec !~ /\{/)) && do
	        {
		    # was /^typedef\s+\S+\s+\(.*\w+.*\)\s*\(.*\);$/smg)) && do
		    my $colordec = $self->functionColor($declaration);
		    $declaration = $colordec;
		    last SWITCH;
	        };
	      my $colordec = $self->complexTypeColor($declaration);
	      $declaration = $colordec;
	  }

	  my $colordec = $self->commentColor($declaration);
	  $declaration = $colordec;
	}

        $self->{DECLARATIONINHTML} = $declaration;
    }
    return $self->{DECLARATIONINHTML};
}

sub availability {
    my $self = shift;

    if (@_) {
        $self->{AVAILABILITY} = shift;
    }
    return $self->{AVAILABILITY};
}

sub lang {
    my $self = shift;

    if (@_) {
        $self->{LANG} = shift;
    }
    return $self->{LANG};
}

sub sublang {
    my $self = shift;

    if (@_) {
	my $sublang = shift;

	if ($sublang eq "occCat") { $sublang = "occ"; }
        $self->{SUBLANG} = $sublang;
    }
    return $self->{SUBLANG};
}

sub updated {
    my $self = shift;
    my $localdebug = 0;
    
    if (@_) {
	my $updated = shift;
        # $self->{UPDATED} = shift;
	my $month; my $day; my $year;

	$month = $day = $year = $updated;

	print "updated is $updated\n" if ($localdebug);
	if (!($updated =~ /\d\d\d\d-\d\d-\d\d/ )) {
	    if (!($updated =~ /\d\d-\d\d-\d\d\d\d/ )) {
		if (!($updated =~ /\d\d-\d\d-\d\d/ )) {
		    # my $filename = $HeaderDoc::headerObject->filename();
		    my $filename = $self->filename();
		    my $linenum = $self->linenum();
		    warn "$filename:$linenum:Bogus date format: $updated.\n";
		    warn "$filename:$linenum:Valid formats are MM-DD-YYYY, MM-DD-YY, and YYYY-MM-DD\n";
		    return $self->{UPDATED};
		} else {
		    $month =~ s/(\d\d)-\d\d-\d\d/$1/smg;
		    $day =~ s/\d\d-(\d\d)-\d\d/$1/smg;
		    $year =~ s/\d\d-\d\d-(\d\d)/$1/smg;

                    my $century;
                    $century = `date +%C`;
                    $century *= 100; 
                    $year += $century;
                    # $year += 2000;
                    print "YEAR: $year" if ($localdebug);
		}
	    } else {
		print "03-25-2003 case.\n" if ($localdebug);
		    $month =~ s/(\d\d)-\d\d-\d\d\d\d/$1/smg;
		    $day =~ s/\d\d-(\d\d)-\d\d\d\d/$1/smg;
		    $year =~ s/\d\d-\d\d-(\d\d\d\d)/$1/smg;
	    }
	} else {
		    $year =~ s/(\d\d\d\d)-\d\d-\d\d/$1/smg;
		    $month =~ s/\d\d\d\d-(\d\d)-\d\d/$1/smg;
		    $day =~ s/\d\d\d\d-\d\d-(\d\d)/$1/smg;
	}
	$month =~ s/\n//smg;
	$day =~ s/\n//smg;
	$year =~ s/\n//smg;
	$month =~ s/\s*//smg;
	$day =~ s/\s*//smg;
	$year =~ s/\s*//smg;

	# Check the validity of the modification date

	my $invalid = 0;
	my $mdays = 28;
	if ($month == 2) {
		if ($year % 4) {
			$mdays = 28;
		} elsif ($year % 100) {
			$mdays = 29;
		} elsif ($year % 400) {
			$mdays = 28;
		} else {
			$mdays = 29;
		}
	} else {
		my $bitcheck = (($month & 1) ^ (($month & 8) >> 3));
		if ($bitcheck) {
			$mdays = 31;
		} else {
			$mdays = 30;
		}
	}

	if ($month > 12 || $month < 1) { $invalid = 1; }
	if ($day > $mdays || $day < 1) { $invalid = 1; }
	if ($year < 1970) { $invalid = 1; }

	if ($invalid) {
		# my $filename = $HeaderDoc::headerObject->filename();
		my $filename = $self->filename();
		my $linenum = $self->linenum();
		warn "$filename:$linenum:Invalid date (year = $year, month = $month, day = $day).\n";
		warn "$filename:$linenum:Valid formats are MM-DD-YYYY, MM-DD-YY, and YYYY-MM-DD\n";
		return $self->{UPDATED};
	} else {
		$self->{UPDATED} = HeaderDoc::HeaderElement::strdate($month, $day, $year);
		print "date set to ".$self->{UPDATED}."\n" if ($localdebug);
	}
    }
    return $self->{UPDATED};
}

sub linkageState {
    my $self = shift;
    
    if (@_) {
        $self->{LINKAGESTATE} = shift;
    }
    return $self->{LINKAGESTATE};
}

sub linkageState {
    my $self = shift;
    
    if (@_) {
        $self->{LINKAGESTATE} = shift;
    }
    return $self->{LINKAGESTATE};
}

sub accessControl {
    my $self = shift;
    
    if (@_) {
        $self->{ACCESSCONTROL} = shift;
    }
    return $self->{ACCESSCONTROL};
}


sub printObject {
    my $self = shift;
    my $dec = $self->declaration();
 
    print "------------------------------------\n";
    print "HeaderElement\n";
    print "name: $self->{NAME}\n";
    print "abstract: $self->{ABSTRACT}\n";
    print "declaration: $dec\n";
    print "declaration in HTML: $self->{DECLARATIONINHTML}\n";
    print "discussion: $self->{DISCUSSION}\n";
    print "linkageState: $self->{LINKAGESTATE}\n";
    print "accessControl: $self->{ACCESSCONTROL}\n\n";
    print "Tagged Parameter Descriptions:\n";
    my $taggedParamArrayRef = $self->{TAGGEDPARAMETERS};
    if ($taggedParamArrayRef) {
	my $arrayLength = @{$taggedParamArrayRef};
	if ($arrayLength > 0) {
	    &printArray(@{$taggedParamArrayRef});
	}
	print "\n";
    }
    my $fieldArrayRef = $self->{CONSTANTS};
    if ($fieldArrayRef) {
        my $arrayLength = @{$fieldArrayRef};
        if ($arrayLength > 0) {
            &printArray(@{$fieldArrayRef});
        }
        print "\n";
    }
}

sub linkfix {
    my $self = shift;
    my $inpString = shift;
    my @parts = split(/\</, $inpString);
    my $first = 1;
    my $outString = "";
    my $localDebug = 0;

    print "Parts:\n" if ($localDebug);
    foreach my $part (@parts) {
	print "$part\n" if ($localDebug);
	if ($first) {
		$outString .= $part;
		$first = 0;
	} else {
		if ($part =~ /^\s*A\s+/i) {
			$part =~ /^(.*?>)/;
			my $linkpart = $1;
			my $rest = $part;
			$rest =~ s/^$1//;

			print "Found link.\nlinkpart: $linkpart\nrest: $rest\n" if ($localDebug);

			if ($linkpart =~ /target\=\".*\"/i) {
			    print "link ok\n" if ($localDebug);
			    $outString .= "<$part";
			} else {
			    print "needs fix.\n" if ($localDebug);
			    $linkpart =~ s/\>$//;
			    $outString .= "<$linkpart target=\"_top\">$rest";
			}
		} else {
			$outString .= "<$part";
		}
	}
    }

    return $outString;
}

sub strdate
{
    my $month = shift;
    my $day = shift;
    my $year = shift;
    my $format = $HeaderDoc::datefmt;

    # print "format $format\n";

    if ($format eq "") {
	return "$month/$day/$year";
    } else  {
	my $dateString = "";
	my $firstsep = "";
	if ($format =~ /^.(.)/) {
	  $firstsep = $1;
	}
	my $secondsep = "";
	if ($format =~ /^...(.)./) {
	  $secondsep = $1;
	}
	SWITCH: {
	  ($format =~ /^M/i) && do { $dateString .= "$month$firstsep" ; last SWITCH; };
	  ($format =~ /^D/i) && do { $dateString .= "$day$firstsep" ; last SWITCH; };
	  ($format =~ /^Y/i) && do { $dateString .= "$year$firstsep" ; last SWITCH; };
	  print "Unknown date format ($format) in config file[1]\n";
	  print "Assuming MDY\n";
	  return "$month/$day/$year";
	}
	SWITCH: {
	  ($format =~ /^..M/i) && do { $dateString .= "$month$secondsep" ; last SWITCH; };
	  ($format =~ /^..D/i) && do { $dateString .= "$day$secondsep" ; last SWITCH; };
	  ($format =~ /^..Y/i) && do { $dateString .= "$year$secondsep" ; last SWITCH; };
	  ($firstsep eq "") && do { last SWITCH; };
	  print "Unknown date format ($format) in config file[2]\n";
	  print "Assuming MDY\n";
	  return "$month/$day/$year";
	}
	SWITCH: {
	  ($format =~ /^....M/i) && do { $dateString .= "$month" ; last SWITCH; };
	  ($format =~ /^....D/i) && do { $dateString .= "$day" ; last SWITCH; };
	  ($format =~ /^....Y/i) && do { $dateString .= "$year" ; last SWITCH; };
	  ($secondsep eq "") && do { last SWITCH; };
	  print "Unknown date format ($format) in config file[3]\n";
	  print "Assuming MDY\n";
	  return "$month/$day/$year";
	}
	return $dateString;
    }
}

sub setStyle
{
    my $self = shift;
    my $name = shift;
    my $style = shift;

    $style =~ s/^\s*//sg;
    $style =~ s/\s*$//sg;

    if (length($style)) {
	%CSS_STYLES->{$name} = $style;
	$HeaderDoc::use_styles = 1;
    }
}

# /*! 
#     This code inserts the discussion from the superclass wherever
#     <hd_ihd/> appears if possible (i.e. where @inheritDoc (HeaderDoc)
#     or {@inheritDoc} (JavaDoc) appears in the original input material.
#     @abstract HTML/XML fixup code to insert superclass discussions
#  */
sub fixup_inheritDoc
{
    my $self = shift;
    my $html = shift;
    my $newhtml = "";

    my @pieces = split(/</, $html);

    foreach my $piece (@pieces) {
	if ($piece =~ s/^hd_ihd\/>//s) {
		if ($self->outputformat() eq "hdxml") {
			$newhtml .= "<hd_ihd>";
		}
		$newhtml .= $self->inheritDoc();
		if ($self->outputformat() eq "hdxml") {
			$newhtml .= "</hd_ihd>";
		}
		$newhtml .= "$piece";
	} else {
		$newhtml .= "<$piece";
	}
    }
    $newhtml =~ s/^<//s;

    return $newhtml;
}

# /*! @function
#     This code inserts values wherever <hd_value/> appears (i.e. where
#     @value (HeaderDoc) or {@value} (JavaDoc) appears in the original
#     input material.
#     @abstract HTML/XML fixup code to insert values
#  */
sub fixup_values
{
    my $self = shift;
    my $html = shift;
    my $newhtml = "";

    my @pieces = split(/</, $html);

    foreach my $piece (@pieces) {
	if ($piece =~ s/^hd_value\/>//s) {
		if ($self->outputformat() eq "hdxml") {
			$newhtml .= "<hd_value>";
		}
		$newhtml .= $self->value();
		if ($self->outputformat() eq "hdxml") {
			$newhtml .= "</hd_value>";
		}
		$newhtml .= "$piece";
	} else {
		$newhtml .= "<$piece";
	}
    }
    $newhtml =~ s/^<//s;

    return $newhtml;
}

sub checkDeclaration
{
    my $self = shift;
    my $class = ref($self) || $self;
    my $keyword = "";
    my $lang = $self->lang();
    my $name = $self->name();
    my $filename = $self->filename();
    my $line = 0;
    my $exit = 0;

    SWITCH: {
	($class eq "HeaderDoc::APIOwner") && do { return 1; };
	($class eq "HeaderDoc::CPPClass") && do { return 1; };
	($class eq "HeaderDoc::Constant") && do { return 1; };
	($class eq "HeaderDoc::Enum") && do { $keyword = "enum"; last SWITCH; };
	($class eq "HeaderDoc::Function") && do { return 1; };
	($class eq "HeaderDoc::Header") && do { return 1; };
	($class eq "HeaderDoc::Method") && do { return 1; };
	($class =~ /^HeaderDoc::ObjC/) && do { return 1; };
	($class eq "HeaderDoc::PDefine") && do { $keyword = "#define"; last SWITCH; };
	($class eq "HeaderDoc::Struct") && do {
			if ($self->isUnion()) {
				$keyword = "union";
			} else {
				if ($lang eq "pascal") {
					$keyword = "record";
				} else {
					$keyword = "struct";
				}
			}
			last SWITCH;
		};
	($class eq "HeaderDoc::Typedef") && do {
				if ($lang eq "pascal") {
					$keyword = "type";
				} else {
					$keyword = "typedef";
				}
				last SWITCH;
			};
	($class eq "HeaderDoc::Var") && do { return 1; };
	{
	    return 1;
	}
    }

    my $declaration = $self->declaration();
    if ($declaration !~ /^\s*$keyword/m &&
        ($lang ne "pascal" || $declaration !~ /\W$keyword\W/m)) {
		if ($class eq "HeaderDoc::Typedef") {
			warn("$filename:$line:Keyword $keyword not found in $name declaration.\n");
			return 0;
		} else {
			if ($declaration !~ /^\s*typedef\s+$keyword/m) {
				warn("$filename:$line:Keyword $keyword not found in $name declaration.\n");
				return 0;
			}
		}
    }

    return 1;
}

sub getStyle
{
    my $self = shift;
    my $name = shift;

   return %CSS_STYLES->{$name};
}

sub styleSheet
{
    my $self = shift;
    my $css = "";

# {
# print "style test\n";
# $self->setStyle("function", "background:#ffff80; color:#000080;");
# $self->setStyle("text", "background:#000000; color:#ffffff;");
# print "results:\n";
	# print "function: \"".$self->getStyle("function")."\"\n";
	# print "text: \"".$self->getStyle("text")."\"\n";
# }


    $css .= "<style type=\"text/css\">";
    $css .= "<!--";
    foreach my $stylename (keys %CSS_STYLES) {
	my $styletext = %CSS_STYLES->{$stylename};
	$css .= ".$stylename {$styletext}";
    }


    $css .= "a:link {text-decoration: none; font-family: lucida grande, geneva, helvetica, arial, sans-serif; font-size: small; color: #0000ff;}";
    $css .= "a:visited {text-decoration: none; font-family: lucida grande, geneva, helvetica, arial, sans-serif; font-size: small; color: #0000ff;}";
    $css .= "a:visited:hover {text-decoration: underline; font-family: lucida grande, geneva, helvetica, arial, sans-serif; font-size: small; color: #ff6600;}";
    $css .= "a:active {text-decoration: none; font-family: lucida grande, geneva, helvetica, arial, sans-serif; font-size: small; color: #ff6600;}";
    $css .= "a:hover {text-decoration: underline; font-family: lucida grande, geneva, helvetica, arial, sans-serif; font-size: small; color: #ff6600;}";
    $css .= "h4 {text-decoration: none; font-family: lucida grande, geneva, helvetica, arial, sans-serif; font-size: tiny; font-weight: bold;}"; # bold
    $css .= "body {text-decoration: none; font-family: lucida grande, geneva, helvetica, arial, sans-serif; font-size: 10pt;}"; # bold
    $css .= "-->";
    $css .= "</style>";

    return $css;
}

sub documentationBlock
{
    my $self = shift;
    my $contentString;
    my $name = $self->name();
    my $desc = $self->discussion();
    my $throws = "";
    my $abstract = $self->abstract();
    my $availability = $self->availability();
    my $updated = $self->updated();
    my $owner = $self->apiOwner();
    my $declaration = $self->declarationInHTML();
    my $declarationRaw = $self->declaration();
    my @constants = $self->constants();
    my @fields = ();
    my @params = ();
    my $result = "";
    my $localDebug = 0;
    # my $apiUIDPrefix = HeaderDoc::APIOwner->apiUIDPrefix();
    my $filename = $self->filename();
    my $linenum = $self->linenum();
    my $list_attributes = $self->getAttributeLists();
    my $short_attributes = $self->getAttributes(0);
    my $long_attributes = $self->getAttributes(1);
    my $class = ref($self) || $self;

    if ($self->can("result")) { $result = $self->result(); }
    if ($self->can("throws")) { $throws = $self->throws(); }
    if ($self->can("fields")) { @fields = $self->fields(); }
    if ($self->can("taggedParameters")){ 
	print "setting params\n" if ($localDebug);
	@params = $self->taggedParameters();
	if ($self->can("parsedParameters")) {
	    $self->taggedParsedCompare();
	}
    } elsif ($self->can("fields")) {
	if ($self->can("parsedParameters")) {
	    $self->taggedParsedCompare();
	}
    } else {
	print "type $class has no taggedParameters function\n" if ($localDebug);
    }

    # $name =~ s/\s*//smg;

    $contentString .= "<hr>";
    # my $uid = "//$apiUIDPrefix/c/func/$name";
       
    # registerUID($uid);
    # $contentString .= "<a name=\"$uid\"></a>\n"; # apple_ref marker

    my $typename = "";
    my $fieldHeading = "";
    my $apiRefType = "";

    my $className = "";
    my $func_or_method = "";

    SWITCH: {
	($class eq "HeaderDoc::Function") && do {
			$typename = "func";
			$fieldHeading = "Parameter Descriptions";
			$apiRefType = "";
			$func_or_method = "function";
		};
	($class eq "HeaderDoc::Constant") && do {
			$typename = "data";
			$fieldHeading = "";
			$apiRefType = "";
		};
	($class eq "HeaderDoc::Enum") && do {
			$typename = "tag";
			$fieldHeading = "Constants";
			$apiRefType = "econst";
		};
	($class eq "HeaderDoc::PDefine") && do {
			$typename = "macro";
			$fieldHeading = "Parameter Descriptions";
			$apiRefType = "";
		};
	($class eq "HeaderDoc::Method") && do {
			$typename = $self->getMethodType($declarationRaw);
			$fieldHeading = "Parameter Descriptions";
			$apiRefType = "";
			if ($owner->can("className")) {  # to get the class name from Category objects
				$className = $owner->className();
			} else {
				$className = $owner->name();
			}
			$func_or_method = "method";
		};
	($class eq "HeaderDoc::Struct") && do {
			$typename = "tag";
			$fieldHeading = "";
			$apiRefType = "";
		};
	($class eq "HeaderDoc::Typedef") && do {
			$typename = "tdef";

        		if ($self->isFunctionPointer()) {
				$fieldHeading = "Parameter Descriptions";
				last SWITCH;
			}
        		if ($self->isEnumList()) {
				$fieldHeading = "Constants";
				last SWITCH;
			}
        		$fieldHeading = "Field Descriptions";

			$apiRefType = "";
			$func_or_method = "function";
		};
	($class eq "HeaderDoc::Var") && do {
			$typename = "data";
			$fieldHeading = "Field Descriptions";
			if ($self->can('isFunctionPointer')) {
			    if ($self->isFunctionPointer()) {
				$fieldHeading = "Parameter Descriptions";
			    }
			}
			$apiRefType = "";
		};
    }
    my $apiref = $self->apiref($typename);
    $contentString .= $apiref;

    $contentString .= "<table border=\"0\"  cellpadding=\"2\" cellspacing=\"2\" width=\"300\">";
    $contentString .= "<tr>";
    $contentString .= "<td valign=\"top\" height=\"12\" colspan=\"5\">";
    $contentString .= "<h2><a name=\"$name\">$name</a></h2>\n";
    $contentString .= "</td>";
    $contentString .= "</tr></table>";
    $contentString .= "<hr>";
    $contentString .= "<dl>";
    if (length($throws)) {
        $contentString .= "<dt><i>Throws:</i></dt>\n<dd>$throws</dd>\n";
    }
    if (length($abstract)) {
        # $contentString .= "<dt><i>Abstract:</i></dt>\n<dd>$abstract</dd>\n";
        $contentString .= "$abstract\n";
    }
    $contentString .= "</dl>";

    if (length($short_attributes)) {
        $contentString .= $short_attributes;
    }
    if (length($list_attributes)) {
        $contentString .= $list_attributes;
    }
    $contentString .= "<blockquote><pre>$declaration</pre></blockquote>\n";

    # if (length($desc)) {$contentString .= "<h5><font face=\"Lucida Grande,Helvetica,Arial\">Discussion</font></h5><p>$desc</p>\n"; }

    if (length($desc)) {$contentString .= "<p>$desc</p>\n"; }
    if (length($long_attributes)) {
        $contentString .= $long_attributes;
    }

    my $arrayLength = @params;
    if (($arrayLength > 0) && (length($fieldHeading))) {
        my $paramContentString;
        foreach my $element (@params) {
            my $fName = $element->name();
            my $fDesc = $element->discussion();
	    my $fType = "";
	    my $apiref = "";

	    if ($self->can("type")) { $fType = $element->type(); }

	    if (length($apiRefType)) {
		$apiref = $element->apiref($apiRefType);
	    }

            if (length ($fName) &&
		(($fType eq 'field') || ($fType eq 'constant') || ($fType eq 'funcPtr') ||
		 ($fType eq ''))) {
                    # $paramContentString .= "<tr><td align=\"center\"><tt>$fName</tt></td><td>$fDesc</td></tr>\n";
                    $paramContentString .= "<dt>$apiref<tt><em>$fName</em></tt></dt><dd>$fDesc</dd>\n";
            } elsif ($fType eq 'callback') {
		my @userDictArray = $element->userDictArray(); # contains elements that are hashes of param name to param doc
		my $paramString;
		foreach my $hashRef (@userDictArray) {
		    while (my ($param, $disc) = each %{$hashRef}) {
			$paramString .= "<dt><b><tt>$param</tt></b></dt>\n<dd>$disc</dd>\n";
		    }
    		    if (length($paramString)) {
			$paramString = "<dl>\n".$paramString."\n</dl>\n";
		    };
		}
		# $contentString .= "<tr><td><tt>$fName</tt></td><td>$fDesc<br>$paramString</td></tr>\n";
		$contentString .= "<dt><tt>$fName</tt></dt><dd>$fDesc<br>$paramString</dd>\n";
	    } else {
		# my $filename = $HeaderDoc::headerObject->name();
		my $classname = ref($self) || $self;
		$classname =~ s/^HeaderDoc:://;
		if (!$HeaderDoc::ignore_apiuid_errors) {
			print "$filename:$linenum:warning: $classname ($name) field with name $fName has unknown type: $fType\n";
		}
	    }
        }
        if (length ($paramContentString)){
            $contentString .= "<h5><font face=\"Lucida Grande,Helvetica,Arial\">$fieldHeading</font></h5>\n";       
            $contentString .= "<blockquote>\n";
            # $contentString .= "<table border=\"1\"  width=\"90%\">\n";
            # $contentString .= "<thead><tr><th>Name</th><th>Description</th></tr></thead>\n";
            $contentString .= "<dl>\n";
            $contentString .= $paramContentString;
            # $contentString .= "</table>\n</blockquote>\n";
            $contentString .= "</dl>\n</blockquote>\n";
        }
    }
    if (@constants) {
        $contentString .= "<h4>Constants</h4>\n";
        $contentString .= "<blockquote>\n";
        $contentString .= "<dl>\n";
        # $contentString .= "<table border=\"1\"  width=\"90%\">\n";
        # $contentString .= "<thead><tr><th>Name</th><th>Description</th></tr></thead>\n";
        foreach my $element (@constants) {
            my $cName = $element->name();
            my $cDesc = $element->discussion();
            # my $uid = "//$apiUIDPrefix/c/econst/$cName";
            # registerUID($uid);
            my $uid = $element->apiuid("econst");
            # $contentString .= "<tr><td align=\"center\"><a name=\"$uid\"><tt>$cName</tt></a></td><td>$cDesc</td></tr>\n";
            $contentString .= "<dt><a name=\"$uid\"><tt>$cName</tt></a></dt><dd>$cDesc</dd>\n";
        }
        # $contentString .= "</table>\n</blockquote>\n";
        $contentString .= "</dl>\n</blockquote>\n";
    }

    if (scalar(@fields)) {
        $contentString .= "<h5><font face=\"Lucida Grande,Helvetica,Arial\">$fieldHeading</font></h5>\n";
        $contentString .= "<blockquote>\n";
        # $contentString .= "<table border=\"1\"  width=\"90%\">\n";
        # $contentString .= "<thead><tr><th>Name</th><th>Description</th></tr></thead>\n";
        $contentString .= "<dl>";

	# foreach my $element (@fields) {
		# print "ETYPE: $element->{TYPE}\n";
	# }

        foreach my $element (@fields) {
            my $fName = $element->name();
            my $fDesc = $element->discussion();
            my $fType = $element->type();

            if (($fType eq 'field') || ($fType eq 'constant') || ($fType eq 'funcPtr')){
                # $contentString .= "<tr><td><tt>$fName</tt></td><td>$fDesc</td></tr>\n";
                $contentString .= "<dt><tt>$fName</tt></dt><dd>$fDesc</dd>\n";
            } elsif ($fType eq 'callback') {
                my @userDictArray = $element->userDictArray(); # contains elements that are hashes of param name to param doc
                my $paramString;
                foreach my $hashRef (@userDictArray) {
                    while (my ($param, $disc) = each %{$hashRef}) {
                        $paramString .= "<dt><b><tt>$param</tt></b></dt>\n<dd>$disc</dd>\n";
                    }
                    if (length($paramString)) {$paramString = "<dl>\n".$paramString."\n</dl>\n";};
                }
                # $contentString .= "<tr><td><tt>$fName</tt></td><td>$fDesc<br>$paramString</td></tr>\n";
                $contentString .= "<dt><tt>$fName</tt></dt><dd>$fDesc<br>$paramString</dd>\n";
            } else {
                my $filename = $HeaderDoc::headerObject->name();
		if (!$HeaderDoc::ignore_apiuid_errors) {
                	print "$filename:0:warning: struct/typdef/union ($name) field with name $fName has unknown type: $fType\n";
			# $element->printObject();
		}
            }
        }

        # $contentString .= "</table>\n</blockquote>\n";
        $contentString .= "</dl>\n</blockquote>\n";
    }

    # if (length($desc)) {$contentString .= "<p>$desc</p>\n"; }
    $contentString .= "<dl>";
    if (length($result)) { 
        $contentString .= "<dt><i>$func_or_method result</i></dt><dd>$result</dd>\n";
    }
    if (length($availability)) {
        $contentString .= "<dt><i>availability</i></dt><dd>$availability</dd>\n";
    }
    if (length($updated)) {
        $contentString .= "<dt><i>updated:</i></dt><dd>$updated</dd>\n";
    }
    $contentString .= "</dl>\n";
    # $contentString .= "<hr>\n";

    my $value_fixed_contentString = $self->fixup_values($contentString);

    return $value_fixed_contentString;    
}


sub taggedParameters {
    my $self = shift;
    if (@_) { 
        @{ $self->{TAGGEDPARAMETERS} } = @_;
    }
    ($self->{TAGGEDPARAMETERS}) ? return @{ $self->{TAGGEDPARAMETERS} } : return ();
}

sub addTaggedParameter {
    my $self = shift;
    if (@_) { 
        push (@{$self->{TAGGEDPARAMETERS}}, @_);
    }
    return @{ $self->{TAGGEDPARAMETERS} };
}

sub parsedParameters
{
    # Override this in subclasses where relevant.
    return ();
}

sub parmfind
{
    my $self = shift;
    my $query = shift;
    my $complistref = shift;
    my @complist = @{$complistref};
    my $compDebug = 0;

warn("IN PARMFIND\n") if ($compDebug);

    foreach my $comp (@complist) {
	warn("parm\n") if ($compDebug);
	my $nscomp = $comp->name();
	$nscomp =~ s/\s*//sg;
	$nscomp =~ s/^\**//ss;
	if (!length($nscomp)) {
		$nscomp = $comp->type();
		$nscomp =~ s/\s*//sg;
	}
	my $nsquery = $query->name;
	$nsquery =~ s/\s*//sg;
	$nsquery =~ s/^\**//ss;
	$nsquery =~ s/^\)*//ss;
	if (!length($nsquery)) {
		$nsquery = $query->type();
		$nsquery =~ s/\s*//sg;
	}
	if ($nscomp eq $nsquery) {
		warn("$nscomp == $nsquery\n") if ($compDebug);
		return 1;
	}
	else {
		warn("$nscomp != $nsquery\n") if ($compDebug);
	}
    }

    warn("Giving up.\n") if ($compDebug);
    return 0;
}

# Compare tagged parameters to parsed parameters (for validation)
sub taggedParsedCompare {
    my $self = shift;
    my @tagged = $self->taggedParameters();
    my @parsed = $self->parsedParameters();
    my $funcname = $self->name();
    my $tpcDebug = 0;
    my $struct = 0;
    my $strict = $HeaderDoc::force_parameter_tagging; # this should be a command-line option eventually.

    if ($self->can("fields")) {
	$struct = 1;
	@tagged = $self->fields();
    }

    if ($HeaderDoc::ignore_apiuid_errors) {
	# This avoids warnings generated by the need to
	# run documentationBlock once prior to the actual parse
	# to generate API references.
	if ($tpcDebug) { print "ignore_apiuid_errors set.  Skipping tagged/parsed comparison.\n"; }
	return;
    }

    if ($self->lang() ne "C") {
	if ($tpcDebug) { print "Language not C.  Skipping tagged/parsed comparison.\n"; }
	return;
    }

    if ($tpcDebug) {
	print "Tagged Parms:\n";
	foreach my $obj (@tagged) {
		print "TYPE: \"" .$obj->type . "\"\nNAME: \"" . $obj->name() ."\"\n";
	}
	print "Parsed Parms:\n";
	foreach my $obj (@parsed) {
		print "TYPE:" .$obj->type . "\nNAME:" . $obj->name()."\n";
	}
    }

    foreach my $tp (@tagged) {
	if ($struct) {
	    my $declaration = $self->declaration();
	    my $tpname = $tp->name();
	    if ($declaration !~ /$tpname/si) {
		my $tpnamestring = $tp->type . " " . $tp->name();
		warn("Function $funcname: parameter $tpnamestring does not appear in declaration.\n");
		# print "DEC is $declaration\n";
	    }
	} else {
	    if (!$self->parmfind($tp, \@parsed)) {
		my $tpname = $tp->type . " " . $tp->name();
		warn("Function $funcname: parameter $tpname does not appear in declaration.\n");
	    }
	}
    }
    if ($strict && !$struct) {
	foreach my $pp (@parsed) {
		if (!$self->parmfind($pp, \@tagged)) {
			my $ppname = $pp->type . " " . $pp->name();
			warn("Function $funcname: parameter $ppname is not tagged.\n");
		}
	}
    }

}

sub parsedParameters {
    my $self = shift;
    if (@_) { 
        @{ $self->{PARSEDPARAMETERS} } = @_;
    }
    ($self->{PARSEDPARAMETERS}) ? return @{ $self->{PARSEDPARAMETERS} } : return ();
}

sub addParsedParameter {
    my $self = shift;
    if (@_) { 
        push (@{$self->{PARSEDPARAMETERS}}, @_);
    }
    return @{ $self->{PARSEDPARAMETERS} };
}


# for subclass/superclass merging
sub parsedParamCompare {
    my $self = shift;
    my $compareObj = shift;
    my @comparelist = $compareObj->parsedParameters();
    my $name = $self->name();
    my $localDebug = 0;

    my @params = $self->parsedParameters();

    if (scalar(@params) != scalar(@comparelist)) { 
	print "parsedParamCompare: function $name arg count differs (".
		scalar(@params)." != ".  scalar(@comparelist) . ")\n" if ($localDebug);
	return 0;
    } # different number of args

    my $pos = 0;
    while ($pos < scalar(@params)) {
	my $compareparam = @comparelist[$pos];
	my $param = @params[$pos];
	if ($compareparam->type() ne $param->type()) {
	    print "parsedParamCompare: function $name no match for argument " .
		$param->name() . ".\n" if ($localDebug);
	    return 0;
	}
	$pos++;
    }

    print "parsedParamCompare: function $name matched.\n" if ($localDebug);
    return 1;
}

sub returntype {
    my $self = shift;
    if (@_) { 
        $self->{RETURNTYPE} = shift;
    }
    return $self->{RETURNTYPE};
}

sub taggedParamMatching
{
    my $self = shift;
    my $name = shift;
    my $localDebug = 0;

    foreach my $param (@{$self->{TAGGEDPARAMETERS}}) {
	my $reducedname = $name;
	my $reducedpname = $param->name;
	$reducedname =~ s/\W//sg;
	$reducedpname =~ s/\W//sg;
	if ($reducedname eq $reducedpname) {
		print "PARAM WAS $param\n" if ($localDebug);
		return $param;
	}
    }

    print "NO SUCH PARAM\n" if ($localDebug);
    return 0;
}

1;
