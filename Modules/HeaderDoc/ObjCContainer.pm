#! /usr/bin/perl -w
#
# Class name: ObjCContainer
# Synopsis: Container for doc declared in an Objective-C interface.
#
#
# Author: Matt Morse (matt@apple.com)
# Last Updated: $Date: 2004/02/09 19:35:19 $
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
BEGIN {
	foreach (qw(Mac::Files)) {
	    $MOD_AVAIL{$_} = eval "use $_; 1";
    }
}
package HeaderDoc::ObjCContainer;

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc printArray printHash);
use HeaderDoc::APIOwner;

# Inheritance
@ISA = qw( HeaderDoc::APIOwner );

use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.20';

################ Portability ###################################
my $isMacOS;
my $pathSeparator;
if ($^O =~ /MacOS/i) {
	$pathSeparator = ":";
	$isMacOS = 1;
} else {
	$pathSeparator = "/";
	$isMacOS = 0;
}
################ General Constants ###################################
my $debugging = 0;
my $tracing = 0;
my $outputExtension = ".html";
my $tocFrameName = "toc.html";
# my $theTime = time();
# my ($sec, $min, $hour, $dom, $moy, $year, @rest);
# ($sec, $min, $hour, $dom, $moy, $year, @rest) = localtime($theTime);
# $moy++;
# $year += 1900;
# my $dateStamp = "$moy/$dom/$year";
######################################################################

sub _initialize {
    my($self) = shift;
    $self->SUPER::_initialize();
    $self->tocTitlePrefix('Class:');
}

sub _getCompositePageString { 
    my $self = shift;
    my $name = $self->name();
    my $compositePageString;
    my $contentString;

    my $abstract = $self->abstract();
    if (length($abstract)) {
	    $compositePageString .= "<h2>Abstract</h2>\n";
	    $compositePageString .= $abstract;
    }

    my $discussion = $self->discussion();
    if (length($discussion)) {
	    $compositePageString .= "<h2>Discussion</h2>\n";
	    $compositePageString .= $discussion;
    }
    
    if ((length($abstract)) || (length($discussion))) {
	    $compositePageString .= "<hr><br>";
    }

    $contentString= $self->_getMethodDetailString(1);
    if (length($contentString)) {
	    $compositePageString .= "<h2>Methods</h2>\n";
		$contentString = $self->stripAppleRefs($contentString);
	    $compositePageString .= $contentString;
    }

    $contentString= $self->_getVarDetailString();
    if (length($contentString)) {
	    $compositePageString .= "<h2>Variables</h2>\n";
		$contentString = $self->stripAppleRefs($contentString);
	    $compositePageString .= $contentString;
    }

    $contentString= $self->_getConstantDetailString();
    if (length($contentString)) {
	    $compositePageString .= "<h2>Constants</h2>\n";
		$contentString = $self->stripAppleRefs($contentString);
	    $compositePageString .= $contentString;
    }
    
    return $compositePageString;
}

sub XMLdocumentationBlock {
    my $self = shift;
    my $compositePageString = "";
    my $name = $self->name();    
    my $abstract = $self->abstract();
    my $discussion = $self->discussion();
    my $updated = $self->updated();
    my $group = $self->group();
    my $contentString;

    if ($self->tocTitlePrefix() eq "Class:") {
	$compositePageString .= "<class type=\"objC\">";
    } else {
	$compositePageString .= "<category type=\"objC\">";
    }

    if (length($name)) {
	$compositePageString .= "<name>$name</name>\n";
    }
    if (length($updated)) {
	$contentString .= "<updated>$updated</updated>\n";
    }
    if (length($group)) {
	$contentString .= "<group>$group</group>\n";
    }

    if (length($abstract)) {
	$compositePageString .= "<abstract>$abstract</abstract>\n";
    }
    if (length($discussion)) {
	$compositePageString .= "<discussion>$discussion</discussion>\n";
    }

    $contentString= $self->_getFunctionXMLDetailString();
    if (length($contentString)) {
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<functions>$contentString</functions>\n";
    }

    $contentString= $self->_getMethodXMLDetailString();
    if (length($contentString)) {
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<methods>$contentString</methods>\n";
    }

    $contentString= $self->_getVarXMLDetailString();
    if (length($contentString)) {
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<globals>$contentString</globals>\n";
    }

    $contentString= $self->_getConstantXMLDetailString();
    if (length($contentString)) {
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<constants>$contentString</constants>\n";
    }
   
    $contentString= $self->_getTypedefXMLDetailString();
    if (length($contentString)) {      
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<typedefs>$contentString</typedefs>";
    }

    $contentString= $self->_getStructXMLDetailString();
    if (length($contentString)) {
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<structs>$contentString</structs>";
    }

    $contentString= $self->_getEnumXMLDetailString();
    if (length($contentString)) {
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<enums>$contentString</enums>";
    }

    $contentString= $self->_getPDefineXMLDetailString();
    if (length($contentString)) {
	$contentString = $self->stripAppleRefs($contentString);
	$compositePageString .= "<defines>$contentString</defines>";
    }

    if ($self->tocTitlePrefix() eq "Class:") {
	$compositePageString .= "</class>";
    } else {
	$compositePageString .= "</category>";
    }

    return $compositePageString;
}


sub getMethodPrefix {
    my $self = shift;
	my $obj = shift;
	my $prefix;
	my $type;
	
	$type = $obj->isInstanceMethod();
	
	if ($type =~ /YES/) {
	    $prefix = "- ";
	} elsif ($type =~ /NO/) {
	    $prefix = "+ ";
	} else {
	    $prefix = "";
	}
	
	return $prefix;
}

sub docNavigatorComment {
    my $self = shift;
    my $name = $self->name();
    $name =~ s/;//sg;
    
    return "<!-- headerDoc=cl; name=$name-->";
}

################## Misc Functions ###################################
sub objName { # used for sorting
    my $obj1 = $a;
    my $obj2 = $b;

    return ($obj1->name() cmp $obj2->name());
}

sub byMethodType { # used for sorting
   my $obj1 = $a;
   my $obj2 = $b;
   if ($HeaderDoc::sort_entries) {
        return ($obj1->isInstanceMethod() cmp $obj2->isInstanceMethod());
   } else {
        return (1 cmp 2);
   }
}

sub byAccessControl { # used for sorting
    my $obj1 = $a;
    my $obj2 = $b;
    return ($obj1->accessControl() cmp $obj2->accessControl());
}

sub objGroup { # used for sorting
   my $obj1 = $a;
   my $obj2 = $b;
   # if ($HeaderDoc::sort_entries) {
        return ($obj1->group() cmp $obj2->group());
   # } else {
        # return (1 cmp 2);
   # }
}

##################### Debugging ####################################

sub printObject {
    my $self = shift;
 
    print "------------------------------------\n";
    print "ObjCContainer\n";
    print "    - no ivars\n";
    print "Inherits from:\n";
    $self->SUPER::printObject();
}

1;
