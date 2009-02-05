#! /usr/bin/perl -w
#
# Module name: BlockParse
# Synopsis: Block parser code
#
# Author: David Gatwood (dgatwood@apple.com)
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
package HeaderDoc::BlockParse;

BEGIN {
	foreach (qw(Mac::Files)) {
	    $MOD_AVAIL{$_} = eval "use $_; 1";
    }
}

use Exporter;
foreach (qw(Mac::Files Mac::MoreFiles)) {
    eval "use $_";
}

$VERSION = 1.02;
@ISA = qw(Exporter);
@EXPORT = qw(blockParse);

use HeaderDoc::Utilities qw(findRelativePath safeName getAPINameAndDisc convertCharsForFileMaker printArray printHash quote parseTokens);

use strict;
use vars qw($VERSION @ISA);
$VERSION = '1.20';

sub peekmatch
{
	my $ref = shift;
	my @stack = @{$ref};
	my $tos = pop(@stack);
	push(@stack, $tos);

	SWITCH: {
	    ($tos eq "{") && do {
			return "}";
		};
	    ($tos eq "#") && do {
			return "#";
		};
	    ($tos eq "(") && do {
			return ")";
		};
	    ($tos eq "/") && do {
			return "/";
		};
	    ($tos eq "'") && do {
			return "'";
		};
	    ($tos eq "\"") && do {
			return "\"";
		};
	    ($tos eq "`") && do {
			return "`";
		};
	    ($tos eq "<") && do {
			return ">";
		};
	    ($tos eq "[") && do {
			return "]";
		};
	    {
		# default case
		warn "Unknown regexp delimiter \"$tos\".  Please file a bug.\n";
		return $tos;
	    };
	}
}

sub blockParse
{
    my $filename = shift;
    my $fileoffset = shift;
    my $inputLinesRef = shift;
    my $inputCounter = shift;
    my $argparse = shift;
    my $ignoreref = shift;
    my $perheaderignoreref = shift;
    my @inputLines = @{$inputLinesRef};
    my $declaration = "";
    my $localDebug   = 0;
    my $listDebug    = 0;
    my $parseDebug   = 0;
    my $sodDebug     = 0;
    my $valueDebug   = 0;
    my $parmDebug    = 0;
    my $cbnDebug     = 0;
    my $macroDebug   = 0;
    my $apDebug      = 0;
    my $typestring = "";
    my $continue = 1;
    my $parsedParamParse = 0;
    my @parsedParamList = ();
    my $lang = $HeaderDoc::lang;
    my $perl = 0;
    my $sublang = $HeaderDoc::sublang;
    my $callback_typedef_and_name_on_one_line = 1;
    my $returntype = "";
    my $freezereturn = 0;

    if ($argparse && $apDebug) { 
	$localDebug   = 1;
	$listDebug    = 1;
	$parseDebug   = 1;
	$sodDebug     = 1;
	$valueDebug   = 1;
	$parmDebug    = 1;
	$cbnDebug     = 1;
	$macroDebug   = 1;
    }
    if ($argparse && ($localDebug || $apDebug)) {
	print "ARGPARSE MODE!\n";
    }

# warn("in BlockParse\n");

    my $inComment = 0;
    my $inInlineComment = 0;
    my $inString = 0;
    my $inChar = 0;
    my $inTemplate = 0;
    my @braceStack = ();

    my $onlyComments = 1;
    my $inMacro = 0;
    my $inBrackets = 0;
    my $inPType = 0;
    my $inRegexp = 0;

    if (0 && $lang eq "C" || $lang eq "java" || $lang eq "Csource") {
	if ($inputLines[$inputCounter] =~ /^\s*#/) {
		my $macro = "";
		my $line = $inputLines[$inputCounter++];

		while ($line =~ /\\\s*$/) {
			$macro .= $line;
			$line = $inputLines[$inputCounter++];
		}
		$macro .= $line;

		my $oneline = $macro;
		$oneline =~ s/\\\s*$//mg;

		if ($oneline =~ /\#(\w+)\s+(\w+)/) {
			my $typestring = $1;
			my $lastsymbol = $2;

			if ($typestring eq "define") {
				$typestring = "#define"; 
# warn("left blockParse (define)\n");
				if ($macro =~ /#define\s+\w+\s*\(/) {
					my $pplref = defParmParse($macro, $inputCounter);
					print "parsedParamList replaced\n" if ($parmDebug);
					@parsedParamList = @{$pplref};
				}
				# print "NumPPs: ".scalar(@parsedParamList)."\n";
				return ($inputCounter, $macro, $typestring, $lastsymbol, "function method", "", \@parsedParamList, "");
			}
		}
		# if we get here, we don't care about this preprocessor directive.
# warn("left blockParse (macro)\n");
		# print "NumPPs: ".scalar(@parsedParamList)."\n";
		return ($inputCounter, $macro, "MACRO", "", "MACRO", "", \@parsedParamList, "");
	}
    }

    # known bug: we don't parse regular expressions very well
    # in perl and other languages.

    my $regexppattern = "";
    my $singleregexppattern = "";
    my $regexpcharpattern = "";
    my @regexpStack = ();
    my ($sotemplate, $eotemplate, $soc, $eoc, $ilc, $sofunction,
	$soprocedure, $sopreproc, $lbrace, $rbrace, $structname,
	$typedefname, $structisbrace) = parseTokens($lang, $sublang);

    if ($lang eq "perl" || $lang eq "shell") {
	$perl = 1;
	$sotemplate = "";
	$eotemplate = "";
	$sopreproc = "";
	$soc = "";
	$eoc = "";
	$ilc = "#";
	if ($lang eq "perl") { $sofunction = "sub"; }
	$lbrace = "{";
	$rbrace = "}";
	$structname = "struct";
	$structisbrace = 0;
	$regexpcharpattern = "/(\{|\#\(|\/|\'|\\\"|\<|\[|\`)/";
	$regexppattern = "/(qq|qr|qx|qw|q|m)/";
	$singleregexppattern = "/(qq|qr|qx|qw|q|m|s|tr|y)/";
    } elsif ($lang eq "pascal") {
	$sotemplate = "";
	$eotemplate = "";
	$sopreproc = "#"; # Some pascal implementations allow #include
	$soc = "{";
	$eoc = "}";
	$ilc = "";
	$sofunction = "function";
	$soprocedure = "procedure";
	$lbrace = "begin";
	$rbrace = "end";
	$structname = "record";
	$structisbrace = 1;
    } else {
	# C and derivatives, plus PHP
	$sotemplate = "<";
	$eotemplate = ">";
	if ($lang eq "C") { $sopreproc = "#"; }
	$soc = "/*";
	$eoc = "*/";
	$ilc = "//";
	$lbrace = "{";
	$rbrace = "}";
	$structname = "struct";
	$structisbrace = 0;
    }

    my $lastsymbol = "";
    my $name = "";
    my $callbackNamePending = 0;
    my $callbackName = "";
    my $callbackIsTypedef = 0;
    my $namePending = 0;
    my $basetype = "";
    my $posstypes = "";
    my $posstypesPending = 1;
    my $sodtype = "";
    my $sodname = "";
    my $sodclass = "";
    my $simpleTypedef = 0;
    my $seenBraces = 0;
    my $kr_c_function = 0;
    my $kr_c_name = "";
    my $lastchar = "";
    my $lastnspart = "";
    my $lasttoken = "";
    my $startOfDec = 1;
    my $prespace = 0;
    my $prespaceadjust = 0;
    my $scratch = "";
    my $curline = "";
    my $curstring = "";
    my $continuation = 0;
    my $forcenobreak = 0;
    my $occmethod = 0;
    my $occspace = 0;
    my $preTemplateSymbol = "";
    my $preEqualsSymbol = "";
    my $valuepending = 0;
    my $value = "";
    my $parsedParam = "";

# print "Prespace test.\n";
# my $n;
# $n = 3;
# my $str = nspaces($n);
# print "STRING: \"$str\"\n";

    while ($continue && ($inputCounter <= $#inputLines)) {
	my $line = $inputLines[$inputCounter++];
	my @parts = ();

	$line =~ s/^\s*//g;
	$line =~ s/\s*$//g;
	# $scratch = nspaces($prespace);
	# $line = "$scratch$line\n";
	# $curline .= $scratch;
	$line .= "\n";

	if ($lang eq "perl" || $lang eq "shell") {
	    @parts = split(/("|'|\#|\{|\}|\(|\)|\s|;|\\|\W)/, $line);
	} else {
	    @parts = split(/("|'|\/\/|\/\*|\*\/|\{|\}|\(|\)|\s|;|\\|\W)/, $line);
	}

	$inInlineComment = 0;

        # warn("line $inputCounter\n");

if ($localDebug) {foreach my $partlist (@parts) {print "PARTLIST: $partlist\n"; }}

	# This block of code needs a bit of explanation, I think.
	# We need to be able to see the token that follows the one we
	# are currently processing.  To do this, we actually keep track
	# of the current token, and the previous token, but name then
	# $nextpart and $part.  We do processing on $part, which gets
	# assigned the value from $nextpart at the end of the loop.
	# To avoid losing the last part of the declaration (or needing
	# to unroll an extra copy of the entire loop code) we push a
	# bogus entry onto the end of the stack, which never gets
	# used (other than as a bogus "next part") because we only
	# process the value in $part.
	push(@parts, "BOGUSBOGUSBOGUSBOGUSBOGUS");
	my $part = "";
	foreach my $nextpart (@parts) {
		print "MYPART: $part\n" if ($localDebug);
	    $forcenobreak = 0;
	    if ($localDebug && $nextpart eq "\n") { print "NEXTPART IS NEWLINE!\n"; }
	    if ($localDebug && $part eq "\n") { print "PART IS NEWLINE!\n"; }
	    if ($nextpart ne "\n" && $nextpart =~ /\s/) {
		# Replace tabs with spaces.
		$nextpart = " ";
	    }
	    if ($part ne "\n" && $part =~ /\s/ && $nextpart ne "\n" &&
		$nextpart =~ /\s/) {
			# we're a space followed by a space.  Drop ourselves.
			next;
	    }
	    print "PART IS \"$part\"\n" if ($localDebug);
	    print "CURLINE IS \"$curline\"\n" if ($localDebug);

	    if (!length($nextpart)) {
		print "SKIP NP\n" if ($localDebug);
		next;
	    }
	    if (!length($part)) {
		print "SKIP PART\n" if ($localDebug);
		$part = $nextpart;
		next;
	    }
	    if ($parseDebug) {
		print "PART: $part, type: $typestring, inComment: $inComment, inInlineComment: $inInlineComment, inChar: $inChar.\n" if ($localDebug);
		print "PART: bracecount: " . scalar(@braceStack) . "\n";
		print "PART: inString: $inString, callbackNamePending: $callbackNamePending, namePending: $namePending, lastsymbol:$lastsymbol, SOL: $startOfDec\n" if ($localDebug);
		print "PART: sodclass: $sodclass sodname: $sodname\n";
		print "PART: posstypes: $posstypes\n";
		print "length(declaration) = " . length($declaration) ."; length(curline) = " . length($curline) . "\n";
	    }
	    SWITCH: {
		(($inMacro == 1) && ($part eq "define")) && do{
			$inMacro = 3;
			$sodname = "";
			last SWITCH;
		};
		(($inMacro == 1) && ($part =~ /(if|ifdef|ifndef|endif|pragma)/)) && do{
			$inMacro = 4;
			$sodname = "";
			last SWITCH;
		};
		($inMacro == 1) && do { $inMacro = 2; };
		($inMacro > 1) && do {
			if ($part =~ /\S/) {
				$lastsymbol = $part;
				if (($sodname eq "") && ($inMacro == 3)) {
					print "DEFINE NAME IS $part\n" if ($macroDebug);
					$sodname = $part;
				}
			}
			$lastchar = $part;
			last SWITCH;
		};
		(length($regexppattern) && $part =~ $regexppattern) && do {
			my $match = $1;
			if ($match =~ $singleregexppattern) {
				# e.g. perl PATTERN?
				$inRegexp = 2;
			} else {
				$inRegexp = 4;
			}
			last SWITCH;
		}; # end regexppattern
		($inRegexp && length($regexpcharpattern) && $part =~ $regexpcharpattern && (!scalar(@regexpStack) || $part eq peekmatch(\@regexpStack))) && do {
			if ($lasttoken eq "\\") {
				# jump to next match.
				next SWITCH;
			}
			if ($part eq "#" &&
			    ((scalar(@regexpStack) != 1) || 
			     (peekmatch(\@regexpStack) ne "#"))) {
				if ($nextpart =~ /^\s/) {
					# it's a comment.  jump to next match.
					next SWITCH;
				}
			}
			if (!scalar(@regexpStack)) {
				push(@regexpStack, $part);
				$inRegexp--;
			} else {
				my $match = peekmatch(\@regexpStack);
				my $tos = pop(@regexpStack);
				if (!scalar(@regexpStack) && ($match eq $part)) {
					$inRegexp--;
					if ($inRegexp == 2 && $tos eq "/") {
						# we don't double the slash in the
						# middle of a s/foo/bar/g style
						# expression.
						$inRegexp--;
					}
					if ($inRegexp) {
						push(@regexpStack, $tos);
					}
				} elsif (scalar(@regexpStack) == 1) {
					push(@regexpStack, $tos);
					if ($tos =~ /['"`]/) {
						# these don't interpolate.
						next SWITCH;
					}
				} else {
					push(@regexpStack, $tos);
					if ($tos =~ /['"`]/) {
						# these don't interpolate.
						next SWITCH;
					}
					push(@regexpStack, $part);
				}
			}
			last SWITCH;
		}; # end regexpcharpattern
		($part eq "$sopreproc") && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				if ($onlyComments) {
					print "inMacro -> 1\n" if ($macroDebug);
					$inMacro = 1;
					$continue = 0;
		    			print "continue -> 0 [1]\n" if ($localDebug);
				}
			    }
			};
		($part eq "$sofunction" || $part eq "$soprocedure") && do {
				$sodclass = "function";
				$kr_c_function = 1;
				$typestring = "function";
				$startOfDec = 0;
				$namePending = 1;
				print "namePending -> 1 [1]\n" if ($parseDebug);
				last SWITCH;
			};
		($part =~ /[-+]/ && $declaration !~ /\S/ && $curline !~ /\S/) && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				print "OCCMETHOD\n" if ($localDebug);
				# Objective C Method.
				$occmethod = 1;
				$lastchar = $part;
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
			    }
			    last SWITCH;
			};
		($part eq $sotemplate) && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar) && !scalar(@braceStack)) {
	print "SBS: " . scalar(@braceStack) . ".\n" if ($localDebug);
				$inTemplate = 1;
				$preTemplateSymbol = $lastsymbol;
				$lastsymbol = "";
				$lastchar = $part;
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
			    }
			    last SWITCH;
			};
		($part eq $eotemplate) && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar) && !scalar(@braceStack)) {
				if ($inTemplate)  {
					$inTemplate = 0;
					$lastsymbol = "";
					$lastchar = $part;
					$curline .= " ";
					$onlyComments = 0;
					print "onlyComments -> 0\n" if ($macroDebug);
				}
			    }
			    last SWITCH;
			};
		($part eq ":" && ($occmethod == 1)) && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				$name = $lastsymbol;
				# Start doing line splitting here.
				# Also, capture the method's name.
				$occmethod = 2;
				if (!$prespace) { $prespaceadjust = 4; }
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
			    }
			    last SWITCH;
			};
		($part =~ /\s/) && do {
				# just add white space silently.
				# if ($part eq "\n") { $lastsymbol = ""; };
				$lastchar = $part;
				last SWITCH;
		};
		($part =~ /\\/) && do { $lastsymbol = $part; $lastchar = $part; };
		($part eq "\"") && do {
				print "dquo\n" if ($localDebug);

				# print "QUOTEDEBUG: CURSTRING IS '$curstring'\n";
				# print "QUOTEDEBUG: CURLINE IS '$curline'\n";
				if (!($inComment || $inInlineComment || $inChar)) {
					$onlyComments = 0;
					print "onlyComments -> 0\n" if ($macroDebug);
					print "LASTTOKEN: $lasttoken\nCS: $curstring\n" if ($localDebug);
					if (($lasttoken !~ /\\$/) && ($curstring !~ /\\$/)) {
						$inString = (1-$inString);
					}
				}
				$lastchar = $part;
				$lastsymbol = "";

				last SWITCH;
			};
		($part eq "[") && do {
				print "lbracket\n" if ($localDebug);

				if (!($inComment || $inInlineComment || $inString)) {
					$onlyComments = 0;
					print "onlyComments -> 0\n" if ($macroDebug);
				}
				push(@braceStack, $part); pbs(@braceStack);
				$curline = spacefix($curline, $part, $lastchar);
				$lastsymbol = "";
				$lastchar = $part;

				last SWITCH;
			};
		($part eq "]") && do {
				print "rbracket\n" if ($localDebug);

				if (!($inComment || $inInlineComment || $inString)) {
					$onlyComments = 0;
					print "onlyComments -> 0\n" if ($macroDebug);
				}
				my $top = pop(@braceStack);
				if ($top ne "[") {
					warn("$filename:$inputCounter:Square brackets do not match.  We may have a problem.\n");
					warn("Declaration to date: $declaration$curline\n");
				}
				pbs(@braceStack);
				$curline = spacefix($curline, $part, $lastchar);
				$lastsymbol = "";
				$lastchar = $part;

				last SWITCH;
			};
		($part eq "'") && do {
				print "squo\n" if ($localDebug);

				if (!($inComment || $inInlineComment || $inString)) { if ($lastchar ne "\\") {
					$onlyComments = 0;
					print "onlyComments -> 0\n" if ($macroDebug);
					$inChar = !$inChar; }
					if ($lastchar =~ /\=$/) {
						$curline .= " ";
					}
				}
				$lastsymbol = "";
				$lastchar = $part;

				last SWITCH;
			};
		($part eq $ilc) && do {
				print "ILC\n" if ($localDebug);

				if (!($inComment || $inChar || $inString)) {
					$inInlineComment = 1;
					$curline = spacefix($curline, $part, $lastchar, $soc, $eoc, $ilc);
				} elsif ($inComment) {
					my $linenum = $inputCounter + $fileoffset;
					if (!$argparse) {
						# We've already seen these.
						warn("$filename:$linenum:Nested comment found [1].  Ignoring.\n");
					}
					# warn("XX $argparse XX $inputCounter XX $fileoffset XX\n");
				}
				$lastsymbol = "";
				$lastchar = $part;

				last SWITCH;
			};
		($part eq $soc) && do {
				print "SOC\n" if ($localDebug);

				if (!($inComment || $inInlineComment || $inChar || $inString)) {
					$inComment = 1; 
					$curline = spacefix($curline, $part, $lastchar);
}
				elsif ($inComment) {
					my $linenum = $inputCounter + $fileoffset;
					warn("$filename:$linenum:Nested comment found [2].  Ignoring.\n");
				}
				$lastsymbol = "";
				$lastchar = $part;

				last SWITCH;
			};
		($part eq $eoc) && do {
				print "EOC\n" if ($localDebug);

				if ($inComment && !($inInlineComment || $inChar || $inString)) {
					$inComment = 0;
					$curline = spacefix($curline, $part, $lastchar);
}
				elsif (!$inComment) {
					my $linenum = $inputCounter + $fileoffset;
					warn("$filename:$linenum:Unmatched close comment tag found.  Ignoring.\n");
				} elsif ($inInlineComment) {
					my $linenum = $inputCounter + $fileoffset;
					warn("$filename:$linenum:Nested comment found [3].  Ignoring.\n");
				}
				$lastsymbol = "";
				$lastchar = $part;

				last SWITCH;
			};
		($part eq "(") && do {
			    my @tempppl = undef;
			    if (!(scalar(@braceStack))) {
				# start parameter parsing after this token
				print "parsedParamParse -> 2\n" if ($parmDebug);
				$parsedParamParse = 2;
				print "parsedParamList wiped\n" if ($parmDebug);
				@tempppl = @parsedParamList;
				@parsedParamList = ();
				$parsedParam = "";
			    }
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				if ($simpleTypedef) {
					$simpleTypedef = 0;
					$sodname = $lastsymbol;
					$sodclass = "function";
					$returntype = "$declaration$curline";
				}
				$posstypesPending = 0;
				if ($callbackNamePending == 2) {
					$callbackNamePending = 3;
					print "callbackNamePending -> 3\n" if ($localDebug || $cbnDebug);
				}
				print "lparen\n" if ($localDebug);

				push(@braceStack, $part); pbs(@braceStack);
				$curline = spacefix($curline, $part, $lastchar);

				print "LASTCHARCHECK: \"$lastchar\" \"$lastnspart\" \"$curline\".\n" if ($localDebug);
				if ($lastnspart eq ")") {  # || $curline =~ /\)\s*$/s
print "HERE: DEC IS $declaration\nENDDEC\nCURLINE IS $curline\nENDCURLINE\n" if ($localDebug);
				    # print "CALLBACKMAYBE: $callbackNamePending $sodclass ".scalar(@braceStack)."\n";
				    print "SBS: ".scalar(@braceStack)."\n" if ($localDebug);
				    if (!$callbackNamePending && ($sodclass eq "function") && (scalar(@braceStack) == 1)) { #  && $argparse
					# Guess it must be a callback anyway.
					my $temp = pop(@tempppl);
					$callbackName = $temp;
					$name = "";
					$sodclass = "";
					$sodname = "";
					print "CALLBACKHERE ($temp)!\n" if ($cbnDebug);
				    }
				    if ($declaration =~ /.*\n(.*?)\n$/s) {
					my $lastline = $1;
print "LL: $lastline\nLLDEC: $declaration" if ($localDebug);
					$declaration =~ s/(.*)\n(.*?)\n$/$1\n/s;
					$curline = "$lastline $curline";
					$curline =~ s/^\s*//s;
					$prespace -= 4;
					$prespaceadjust += 4;
					
					$forcenobreak = 1;
print "NEWDEC: $declaration\nNEWCURLINE: $curline\n" if ($localDebug);
				    } elsif (length($declaration) && $callback_typedef_and_name_on_one_line) {
print "SCARYCASE\n" if ($localDebug);
					$declaration =~ s/\n$//s;
					$curline = "$declaration $curline";
					$declaration = "";
					$prespace -= 4;
					$prespaceadjust += 4;
					
					$forcenobreak = 1;
				    }
				} else { print "OPARENLC: \"$lastchar\"\nCURLINE IS: \"$curline\"\n" if ($localDebug);}

				$lastsymbol = "";
				$lastchar = $part;

				if ($startOfDec == 2) {
					$sodclass = "function";
					$freezereturn = 1;
					$returntype =~ s/^\s*//s;
					$returntype =~ s/\s*$//s;
				}
				$startOfDec = 0;
				if ($curline !~ /\S/) {
					# This is the first symbol on the line.
					# adjust immediately
					$prespace += 4;
					print "PS: $prespace immediate\n" if ($localDebug);
				} else {
					$prespaceadjust += 4;
					print "PSA: $prespaceadjust\n" if ($localDebug);
				}
			    }
			    print "OUTGOING CURLINE: \"$curline\"\n" if ($localDebug);
			    last SWITCH;
			};
		($part eq ")") && do {
			    if (scalar(@braceStack) == 1) {
				# stop parameter parsing
				$parsedParamParse = 0;
				print "parsedParamParse -> 0\n" if ($parmDebug);
				$parsedParam =~ s/^\s*//s; # trim leading space
				$parsedParam =~ s/\s*$//s; # trim trailing space

				if ($parsedParam ne "void") {
					# ignore foo(void)
					push(@parsedParamList, $parsedParam);
					print "pushed $parsedParam into parsedParamList [1]\n" if ($parmDebug);
				}
				$parsedParam = "";
			    }
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				print "rparen\n" if ($localDebug);


				my $test = pop(@braceStack); pbs(@braceStack);
				if (!($test eq "(")) {		# ) brace hack for vi
					warn("$filename:$inputCounter:Parentheses do not match.  We may have a problem.\n");
					warn("Declaration to date: $declaration$curline\n");
				}
				$curline = spacefix($curline, $part, $lastchar);
				$lastsymbol = "";
				$lastchar = $part;

				$startOfDec = 0;
				if ($curline !~ /\S/) {
					# This is the first symbol on the line.
					# adjust immediately
					$prespace -= 4;
					print "PS: $prespace immediate\n" if ($localDebug);
				} else {
					$prespaceadjust -= 4;
					print "PSA: $prespaceadjust\n" if ($localDebug);
				}
			    }
			    last SWITCH;
			};
		($part eq "$lbrace") && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				# if ($lang eq "perl") {
					# @@@ HACK HACK HACK
					# Delete me and the hack a few dozen
					# lines down when the parser knows
					# how to parse regular expressions
					# without choking and when we've
					# taught the upper layer not to
					# attempt any structured types....
		    			# print "continue -> 0 [2]\n" if ($localDebug);
					# $continue = 0; last;
				# }
				if ($sodclass eq "function") {
					$seenBraces = 1;
				}
				$posstypesPending = 0;
				$namePending = 0;
				$callbackNamePending = -1;
				$simpleTypedef = 0;
				print "callbackNamePending -> -1\n" if ($localDebug || $cbnDebug);
				print "lbrace\n" if ($localDebug);

				push(@braceStack, $part); pbs(@braceStack);
				$curline = spacefix($curline, $part, $lastchar);
				$lastsymbol = "";
				$lastchar = $part;

				$startOfDec = 0;
				if ($curline !~ /\S/) {
					# This is the first symbol on the line.
					# adjust immediately
					$prespace += 4;
					print "PS: $prespace immediate\n" if ($localDebug);
				} else {
					$prespaceadjust += 4;
					print "PSA: $prespaceadjust\n" if ($localDebug);
				}
			    }
			    last SWITCH;
			};
		($part eq "$rbrace") && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				print "rbrace\n" if ($localDebug);

				my $test = pop(@braceStack); pbs(@braceStack);
				if (!($test eq "$lbrace") && (!length($structname) || (!($test eq $structname) && $structisbrace))) {		# } brace hack for vi.
					warn("$filename:$inputCounter:Braces do not match.  We may have a problem.\n");
					warn("Declaration to date: $declaration$curline\n");
				}
				$curline = spacefix($curline, $part, $lastchar);
				$lastsymbol = "";
				$lastchar = $part;

				$startOfDec = 0;
				if ($curline !~ /\S/) {
					# This is the first symbol on the line.
					# adjust immediately
					$prespace -= 4;
					print "PS: $prespace immediate\n" if ($localDebug);
				} else {
					$prespaceadjust -= 4;
					print "PSA: $prespaceadjust\n" if ($localDebug);
				}
			    }
			    last SWITCH;
			};
		($part eq $structname || $part =~ /^enum$/ || $part =~ /^union$/) && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				if ($structisbrace) {
                                	if ($sodclass eq "function") {
                                        	$seenBraces = 1;
                                	}
                                	$posstypesPending = 0;
                                	$callbackNamePending = -1;
                                	$simpleTypedef = 0;
                                	print "callbackNamePending -> -1\n" if ($localDebug || $cbnDebug);
                                	print "lbrace\n" if ($localDebug);

                                	push(@braceStack, $part); pbs(@braceStack);
                                	$curline = spacefix($curline, $part, $lastchar);
                                	$lastsymbol = "";
                                	$lastchar = $part;

                                	$startOfDec = 0;
                                	if ($curline !~ /\S/) {
                                        	# This is the first symbol on the line.
                                        	# adjust immediately
                                        	$prespace += 4;
                                        	print "PS: $prespace immediate\n" if ($localDebug);
                                	} else {
                                        	$prespaceadjust += 4;
                                        	print "PSA: $prespaceadjust\n" if ($localDebug);
                                	}
				} else {
					$simpleTypedef = 1;
				}
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				$continuation = 1;
				# $simpleTypedef = 0;
				if ($basetype eq "") { $basetype = $part; }
				# fall through to default case when we're done.
				if (!($inComment || $inInlineComment || $inString || $inChar)) {
					$namePending = 2;
					print "namePending -> 2 [2]\n" if ($parseDebug);
					if ($posstypesPending) { $posstypes .=" $part"; }
				}
				if ($sodclass eq "") {
					$startOfDec = 0; $sodname = "";
print "sodname cleared (seu)\n" if ($sodDebug);
				}
				$lastchar = $part;
			    }; # end if
			}; # end do
		($part =~ /^$typedefname$/) && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				if (!scalar(@braceStack)) { $callbackIsTypedef = 1; }
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				$continuation = 1;
				$simpleTypedef = 1;
				# previous case falls through, so be explicit.
				if ($part =~ /^$typedefname$/) {
				    if (!($inComment || $inInlineComment || $inString || $inChar)) {
					if ($lang eq "pascal") {
					    $namePending = 2;
					    $inPType = 1;
					    print "namePending -> 2 [3]\n" if ($parseDebug);
					}
					if ($posstypesPending) { $posstypes .=" $part"; }
					if (!($callbackNamePending)) {
						print "callbackNamePending -> 1\n" if ($localDebug || $cbnDebug);
						$callbackNamePending = 1;
					}
				    }
				}
				if ($sodclass eq "") {
					$startOfDec = 0; $sodname = "";
print "sodname cleared ($typedefname)\n" if ($sodDebug);
				}
				$lastchar = $part;
			    }; # end if
			}; # end do
		($part =~ /;/) && do {
			    if (!($inString || $inComment || $inInlineComment || $inChar)) {
				$freezereturn = 1;
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				print "valuepending -> 0\n" if ($valueDebug);
				$valuepending = 0;
				$continuation = 1;
				if ($occmethod) {
					$prespaceadjust = -$prespace;
				}
				# previous case falls through, so be explicit.
				if ($part =~ /;/) {
				    my $bsCount = $#braceStack + 1;
				    if (!$bsCount && !$kr_c_function) {
					if ($startOfDec == 2) {
						$sodclass = "constant";
						$startOfDec = 1;
					} elsif (!($inComment || $inInlineComment || $inChar || $inString)) {
						$startOfDec = 1;
					}
					# $lastsymbol .= $part;
				    }
				}
				$lastchar = $part;
			    }; # end if
			}; # end do
		($part =~ /=/ && ($lastsymbol ne "operator")) && do {
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
				if ($part =~ /=/ && !scalar(@braceStack) &&
				    $nextpart !~ /=/ && $lastchar !~ /=/ &&
				    $sodclass ne "function" && !$inPType) {
					print "valuepending -> 1\n" if ($valueDebug);
					$valuepending = 1;
					$preEqualsSymbol = $lastsymbol;
					$sodclass = "constant";
					$startOfDec = 0;
				}; # end if
			}; # end do
		($part =~ /,/) && do {
				if (!($inString || $inComment || $inInlineComment || $inChar)) {
					$onlyComments = 0;
					print "onlyComments -> 0\n" if ($macroDebug);
				}
				if ($part =~ /,/ && $parsedParamParse && (scalar(@braceStack) == 1)) {
					$parsedParam =~ s/^\s*//s; # trim leading space
					$parsedParam =~ s/\s*$//s; # trim trailing space
					push(@parsedParamList, $parsedParam);
					print "pushed $parsedParam into parsedParamList [2]\n" if ($parmDebug);
					$parsedParam = "";
					# skip this token
					$parsedParamParse = 2;
					print "parsedParamParse -> 2\n" if ($parmDebug);
				}; # end if
			}; # end do
		{ # SWITCH default case
	# print "TEST CURLINE IS \"$curline\".\n";
		    if (!($inString || $inComment || $inInlineComment || $inChar)) {
		      if (!ignore($part, $ignoreref, $perheaderignoreref)) {
			if ($part =~ /\S/) {
				$onlyComments = 0;
				print "onlyComments -> 0\n" if ($macroDebug);
			}
			if (!$continuation && !$occspace) {
				$curline = spacefix($curline, $part, $lastchar);
			} else {
				$continuation = 0;
				$occspace = 0;
			}
	# print "BAD CURLINE IS \"$curline\".\n";
			if (length($part) && !($inComment || $inInlineComment)) {
				if ($localDebug && $lastchar eq ")") {print "LC: $lastchar\nPART: $part\n";}
				if ($lastchar eq ")" && $sodclass eq "function" && $lang eq "C") {
					if ($part !~ /^\s*;/) {
						# warn "K&R C FUNCTION FOUND.\n";
						# warn "NAME: $sodname\n";
						$kr_c_function = 1;
						$kr_c_name = $sodname;
					}
				}
				$lastchar = $part;
				if ($part =~ /\w/) {
				    if ($callbackNamePending == 1) {
					if (!($part =~ /^struct$/ || $part =~ /^enum$/ || $part =~ /^union$/ || $part =~ /^$typedefname$/)) {
						# we've seen the initial type.  The name of
						# the callback is after the next open
						# parenthesis.
						print "callbackNamePending -> 2\n" if ($localDebug || $cbnDebug);
						$callbackNamePending = 2;
					}
				    } elsif ($callbackNamePending == 3) {
					print "callbackNamePending -> 0\n" if ($localDebug || $cbnDebug);
					$callbackNamePending = 0;
					$callbackName = $part;
					$name = "";
					$sodclass = "";
					$sodname = "";
				    }
				    if ($namePending == 2) {
					$namePending = 1;
					print "namePending -> 1 [4]\n" if ($parseDebug);
				    } elsif ($namePending) {
					if ($name eq "") { $name = $part; }
					$namePending = 0;
					print "namePending -> 0 [5]\n" if ($parseDebug);
				    }
				} # end if ($part =~ /\w/)
				if ($part !~ /[;\[\]]/ && !$inBrackets)  {
					if ($startOfDec == 1) {
						print "Setting sodname (maybe type) to \"$part\"\n" if ($sodDebug);
						$sodname = $part;
						if ($part =~ /\w/) {
							$startOfDec++;
						}
					} elsif ($startOfDec == 2) {
						if ($part =~ /\w/ && !$inTemplate) {
							$preTemplateSymbol = "";
						}
						if (length($sodname)) {
							$sodtype .= " $sodname";
						}
						$sodname = $part;
print "sodname set to $part\n" if ($sodDebug);
					} else {
						$startOfDec = 0;
					}
				} elsif ($part eq "[") { # if ($part !~ /[;\[\]]/)
					$inBrackets += 1;
					print "inBrackets -> $inBrackets\n" if ($sodDebug);
				} elsif ($part eq "]") {
					$inBrackets -= 1;
					print "inBrackets -> $inBrackets\n" if ($sodDebug);
				} # end if ($part !~ /[;\[\]]/)
				if (!($part eq $eoc)) {
					if ($typestring eq "") { $typestring = $part; }
					if ($lastsymbol =~ /\,\s*$/) {
						$lastsymbol .= $part;
					} elsif ($part =~ /^\s*\;\s*$/) {
						$lastsymbol .= $part;
					} elsif (length($part)) {
						# warn("replacing lastsymbol with \"$part\"\n");
						$lastsymbol = $part;
					}
				} # end if (!($part eq $eoc))
			} # end if (length($part) && !($inComment || $inInlineComment))
		      }
		    } # end if (!($inString || $inComment || $inInlineComment || $inChar))
		} # end SWITCH default case
		if (length($part)) { $lasttoken = $part; }
	    } # end SWITCH


	    if (!$freezereturn) {
		$returntype = "$declaration$curline";
 	    }

	    if (($inString || $inComment || $inInlineComment || $inChar) ||
		!ignore($part, $ignoreref, $perheaderignoreref)) {
	        if ($parsedParamParse == 1) {
		    $parsedParam .= $part;
	        } elsif ($parsedParamParse == 2) {
		    $parsedParamParse = 1;
		    print "parsedParamParse -> 1\n" if ($parmDebug);
	        }
		print "MIDPOINT CL: $curline\nDEC:$declaration\nSCR: \"$scratch\"\n" if ($localDebug);
	        if (!$seenBraces) {
		    # Add to current line (but don't put inline function/macro
		    # declarations in.

		    if ($inString) {
			$curstring .= $part;
		    } else {
			if (length($curstring)) {
				if (length($curline) + length($curstring) >
				    $HeaderDoc::maxDecLen) {
					$scratch = nspaces($prespace);
					# @@@ WAS != /\n/ which is clearly
					# wrong.  Suspect the next line
					# if we start losing leading spaces
					# where we shouldn't (or don't where
					# we should).  Also was just /g.
					if ($curline !~ /^\s*\n/s) { $curline =~ s/^\s*//sg; }
					
					# NEWLINE INSERT
					print "CURLINE CLEAR [1]\n" if ($localDebug);
					$declaration .= "$scratch$curline\n";
					$curline = "";
					$prespace += $prespaceadjust;
					$prespaceadjust = 0;
					$prespaceadjust -= 4;
					$prespace += 4;
				} else {
					# no wrap, so maybe add a space.
					if ($lastchar =~ /\=$/) {
						$curline .= " ";
					}
				}
				$curline .= $curstring;
				$curstring = "";
			}
			if ((length($curline) + length($part) > $HeaderDoc::maxDecLen)) {
				$scratch = nspaces($prespace);
				# @@@ WAS != /\n/ which is clearly
				# wrong.  Suspect the next line
				# if we start losing leading spaces
				# where we shouldn't (or don't where
				# we should).  Also was /g instead of /sg.
				if ($curline !~ /^\s*\n/s) { $curline =~ s/^\s*//sg; }
				# NEWLINE INSERT
				$declaration .= "$scratch$curline\n";
				print "CURLINE CLEAR [2]\n" if ($localDebug);
				$curline = "";
				$prespace += $prespaceadjust;
				$prespaceadjust = 0;
				$prespaceadjust -= 4;
				$prespace += 4;
			}
			if (length($curline) || $part ne " ") {
				# Add it to curline unless it's a space that
				# has inadvertently been wrapped to the
				# start of a line.
				$curline .= $part;
			}
		    }
		    if ($part =~ /\n/ || ($part =~ /[\(;,]/ && $nextpart !~ /\n/ &&
		                      !$occmethod) ||
                                     ($part =~ /[:;.]/ && $nextpart !~ /\n/ &&
                                      $occmethod)) {
			if ($curline !~ /\n/ && !($inMacro || ($lang eq "pascal" && scalar(@braceStack)) || $inInlineComment || $inComment || $inString)) {
				# NEWLINE INSERT
				$curline .= "\n";
			}
			# Add the current line to the declaration.

			$scratch = nspaces($prespace);
			if ($curline !~ /\n/) { $curline =~ s/^\s*//g; }
			if ($declaration !~ /\n\s*$/) {
				$scratch = " ";
				if ($localDebug) {
					my $zDec = $declaration;
					$zDec = s/ /z/sg;
					$zDec = s/\t/Z/sg;
					print "ZEROSCRATCH\n";
					print "zDec: \"$zDec\"\n";
				}
			}
			$declaration .= "$scratch$curline";
				print "CURLINE CLEAR [3]\n" if ($localDebug);
			$curline = "";
			# $curline = nspaces($prespace);
			print "PS: $prespace -> " . $prespace + $prespaceadjust . "\n" if ($localDebug);
			$prespace += $prespaceadjust;
			$prespaceadjust = 0;
		    } elsif ($part =~ /[\(;,]/ && $nextpart !~ /\n/ &&
                                      ($occmethod == 1)) {
			print "SPC\n" if ($localDebug);
			$curline .= " "; $occspace = 1;
		    } else {
			print "NOSPC: $part:$nextpart:$occmethod\n" if ($localDebug);
		    }
		}
	        print "CURLINE IS \"$curline\".\n" if ($localDebug);
	        my $bsCount = $#braceStack + 1;
	        if (!$bsCount && $lastsymbol =~ /;\s*$/) {
		    if (!$kr_c_function || $seenBraces) {
			    $continue = 0;
			    print "continue -> 0 [3]\n" if ($localDebug);
		    }
	        } else {
		    print("bsCount: $bsCount, ls: $lastsymbol\n") if ($localDebug);
	        }
	        if (!$bsCount && $seenBraces && ($sodclass eq "function") && 
		    ($nextpart ne ";")) {
			# Function declarations end at the close curly brace.
			# No ';' necessary (though we'll eat it if it's there.
			$continue = 0;
			print "continue -> 0 [4]\n" if ($localDebug);
	        }
	        if (($inMacro == 3 && $lastsymbol eq "\\") || $inMacro == 4) {
		    $continue = 0;
		    print "continue -> 0 [5]\n" if ($localDebug);
	        } elsif ($inMacro == 2) {
		    warn "Declaration starts with # but is not preprocessor macro\n";
	        }
	        if ($valuepending == 2) {
		    # skip the "=" part;
		    $value .= $part;
	        } elsif ($valuepending) {
		    $valuepending = 2;
		    print "valuepending -> 2\n" if ($valueDebug);
	        }
	    } # end if "we're not ignoring this token"

	    if (length($part) && $part =~ /\S/) { $lastnspart = $part; }
	    $part = $nextpart;
	}
    }
    if ($curline !~ /\n/) { $curline =~ s/^\s*//g; }
    if ($curline =~ /\S/) {
	$scratch = nspaces($prespace);
	$declaration .= "$scratch$curline\n";
    }

    print "($typestring, $basetype)\n" if ($localDebug || $listDebug);

    print "LS: $lastsymbol\n" if ($localDebug);
    # if ($simpleTypedef) { $name = ""; }

    my $typelist = "";
    my $namelist = "";
    my @names = split(/[,\s;]/, $lastsymbol);
    foreach my $insname (@names) {
	$insname =~ s/\s//s;
	$insname =~ s/^\*//sg;
	if (length($insname)) {
	    $typelist .= " $typestring";
	    $namelist .= ",$insname";
	}
    }
    $typelist =~ s/^ //;
    $namelist =~ s/^,//;

    if ($lang eq "pascal") {
	# Pascal only has one name for a type, and it follows the word "type"
	if (!length($typelist)) {
		$typelist .= "$typestring";
		$namelist .= "$name";
	}
    }

print "TL (PRE): $typelist\n" if ($localDebug);

    if (!length($basetype)) { $basetype = $typestring; }
print "BT: $basetype\n" if ($localDebug);

print "NAME is $name\n" if ($localDebug || $listDebug);

# print $HeaderDoc::outerNamesOnly . " or " . length($namelist) . ".\n";

    # If the name field contains a value, and if we've seen at least one brace or parenthesis
    # (to avoid "typedef struct foo bar;" giving us an empty declaration for struct foo), and
    # if either we want tag names (foo in "struct foo { blah } foo_t") or there is no name
    # other than a tag name (foo in "struct foo {blah}"), then we give the tag name.  Scary
    # little bit of logic.  Sorry for the migraine.

    if ($name && length($name) && !$simpleTypedef && (!$HeaderDoc::outerNamesOnly || !length($namelist))) {
	my $quotename = quote($name);
	if ($namelist !~ /$quotename/) {
		if (length($namelist)) {
			$namelist .= ",";
			$typelist .= " ";
		}
		$namelist .= "$name";
		$typelist .= "$basetype";
	}
    } else {
	# if we never found the name, it might be an anonymous enum,
	# struct, union, etc.

	if (!scalar(@names)) {
		print "Empty output ($basetype, $typestring).\n" if ($localDebug || $listDebug);
		$namelist = " ";
		$typelist = "$basetype";
	}

	print "NUMNAMES: ".scalar(@names)."\n" if ($localDebug || $listDebug);
    }

print "NL: \"$namelist\".\n" if ($localDebug || $listDebug);
print "TL: \"$typelist\".\n" if ($localDebug || $listDebug);
print "PT: \"$posstypes\"\n" if ($localDebug || $listDebug);

    $callbackName =~ s/^.*:://;
    $callbackName =~ s/^\*+//;
    print "CBN: \"$callbackName\"\n" if ($localDebug || $listDebug);
    if (length($callbackName)) {
	$name = $callbackName;
	print "DEC: \"$declaration\"\n" if ($localDebug || $listDebug);
	$namelist = $name;
	if ($callbackIsTypedef) {
		$typelist = "typedef";
		$posstypes = "function";
	} else {
		$typelist = "function";
		$posstypes = "typedef";
	}
	print "NL: \"$namelist\".\n" if ($localDebug || $listDebug);
	print "TL: \"$typelist\".\n" if ($localDebug || $listDebug);
	print "PT: \"$posstypes\"\n" if ($localDebug || $listDebug);

	# my $newdec = "";
	# my $firstpart = 2;
	# foreach my $decpart (split(/\n/, $declaration)) {
		# if ($firstpart == 2) {
			# $newdec .= "$decpart ";
			# $firstpart--;
		# } elsif ($firstpart) {
			# $decpart =~ s/^\s*//;
			# $newdec .= "$decpart\n";
			# $firstpart--;
		# } else {
			# $newdec .= "$decpart\n";
		# }
	# }
	# $declaration = $newdec;
    }

    if (length($preTemplateSymbol)) {
	$sodname = $preTemplateSymbol;
	$sodclass = "ftmplt";
	$posstypes = "ftmplt function method"; # can it really be a method?
    }

    print "TVALUE: $value\n" if ($localDebug);
    if ($sodclass ne "constant") {
	$value = "";
    } elsif (length($value)) {
	$value =~ s/^\s*//s;
	$value =~ s/\s*$//s;
	$posstypes = "constant";
	$sodname = $preEqualsSymbol;
    }

    # We lock in the name prior to walking through parameter names for
    # K&R C-style declarations.  Restore that name first.
    if (length($kr_c_name)) { $sodname = $kr_c_name; $sodclass = "function"; }

    if (length($sodname) && !$occmethod) {
	if (!length($callbackName)) { # && $callbackIsTypedef
	    if (!$perl) {
		$name = $sodname;
		$namelist = $name;
	    }
	    $typelist = "$sodclass";
	    if (!length($preTemplateSymbol)) {
	        $posstypes = "$sodclass";
	    }
	    print "SETTING NAME/TYPE TO $sodname, $sodclass\n" if ($sodDebug);
	    if ($sodclass eq "function") {
		$posstypes .= " method";
	    }
	}
    }

    print "DEC: $declaration\n" if ($sodDebug || $localDebug);
    if ($occmethod) {
	$typelist = "method";
	$posstypes = "method function";
	if ($occmethod == 2) {
		$namelist = "$name";
	}
    }

    # if ($lang eq "perl") {
	# @@@ HACK HACK HACK
	# Delete me and the hack a few dozen
	# lines up when the parser knows
	# how to parse regular expressions
	# without choking and when we've
	# taught the upper layer not to
	# attempt any structured types....
	$declaration =~ s/\{\s*$//sg;
	# if ($declaration !~ /\(/) {
		# $declaration .= "(...)";
	# }
	# $declaration .= ";";
    # }

    if ($inMacro == 3) {
	$typelist = "#define";
	$posstypes = "function method";
	$namelist = $sodname;
	$value = "";
	@parsedParamList = ();
	if ($declaration =~ /#define\s+\w+\s*\(/) {
		my $pplref = defParmParse($declaration, $inputCounter);
		print "parsedParamList replaced\n" if ($parmDebug);
		@parsedParamList = @{$pplref};
	} else {
		# It can't be a function-like macro, but it could be
		# a constant.
		$posstypes = "constant";
	}
    } elsif ($inMacro == 4) { 
	$typelist = "MACRO";
	$posstypes = "MACRO";
	$value = "";
	@parsedParamList = ();
    }

print "TYPELIST WAS \"$typelist\"\n" if ($localDebug);;
# warn("left blockParse (macro)\n");
# print "NumPPs: ".scalar(@parsedParamList)."\n";
print "LEFTBP\n" if ($localDebug);
return ($inputCounter, $declaration, $typelist, $namelist, $posstypes, $value, \@parsedParamList, $returntype);
}

sub spacefix
{
my $curline = shift;
my $part = shift;
my $lastchar = shift;
my $soc = shift;
my $eoc = shift;
my $ilc = shift;
my $localDebug = 0;

print "SF: \"$curline\" \"$part\" \"$lastchar\"\n" if ($localDebug);

	if (($part !~ /[;,]/)
	  && length($curline)) {
		# space before most tokens, but not [;,]
		if ($part eq $ilc) {
				if ($lastchar ne " ") {
					$curline .= " ";
				}
				last SWITCH;
			}
		if ($part eq $soc) {
				if ($lastchar ne " ") {
					$curline .= " ";
				}
				last SWITCH;
			}
		if ($part eq $eoc) {
				if ($lastchar ne " ") {
					$curline .= " ";
				}
				last SWITCH;
			}
		if ($part =~ /\(/) {
print "PAREN\n" if ($localDebug);
			if ($curline !~ /[\)\w\*]\s*$/) {
				print "CASEA\n" if ($localDebug);
				if ($lastchar ne " ") {
					print "CASEB\n" if ($localDebug);
					$curline .= " ";
				}
			} else {
				print "CASEC\n" if ($localDebug);
				$curline =~ s/\s*$//;
			}
		} elsif ($part =~ /^\w/) {
			if ($lastchar eq "\$") {
				$curline =~ s/\s*$//;
			} elsif ($part =~ /^\d/ && $curline =~ /-$/) {
				$curline =~ s/\s*$//;
			} elsif ($curline !~ /[\*\(]\s*$/) {
				if ($lastchar ne " ") {
					$curline .= " ";
				}
			} else {
				$curline =~ s/\s*$//;
			}
		} elsif ($lastchar =~ /\w/) {
			#($part =~ /[=!+-\/\|\&\@\*/ etc.)
			$curline .= " ";
		}
	}

	if ($curline =~ /\/\*$/) { $curline .= " "; }

	return $curline;
}

sub nspaces
{
    my $n = shift;
    my $string = "";

    while ($n-- > 0) { $string .= " "; }
    return $string;
}

sub pbs
{
    my @braceStack = shift;
    my $localDebug = 0;

    if ($localDebug) {
	print "BS: ";
	foreach my $p (@braceStack) { print "$p "; }
	print "ENDBS\n";
    }
}

# parse #define arguments
sub defParmParse
{
    my $declaration = shift;
    my $inputCounter = shift;
    my @myargs = ();
    my $localDebug = 0;
    my $curname = "";
    my $filename = "";

    $declaration =~ s/.*#define\s+\w+\s*\(//;
    my @braceStack = ( "(" );

    my @tokens = split(/(\W)/, $declaration);
    foreach my $token (@tokens) {
	print "TOKEN: $token\n" if ($localDebug);
	if (!scalar(@braceStack)) { last; }
	if ($token =~ /[\(\[]/) {
		print "open paren/bracket - $token\n" if ($localDebug);
		push(@braceStack, $token);
	} elsif ($token =~ /\)/) {
		print "close paren\n" if ($localDebug);
		my $top = pop(@braceStack);
		if ($top !~ /\(/) {
			warn("$filename:$inputCounter:Parentheses do not match (macro).  We may have a problem.\n");
		}
	} elsif ($token =~ /\]/) {
		print "close bracket\n" if ($localDebug);
		my $top = pop(@braceStack);
		if ($top !~ /\[/) {
			warn("$filename:$inputCounter:Braces do not match (macro).  We may have a problem.\n");
		}
	} elsif ($token =~ /,/ && (scalar(@braceStack) == 1)) {
		$curname =~ s/^\s*//sg;
		$curname =~ s/\s*$//sg;
		push(@myargs, $curname);
		print "pushed \"$curname\"\n" if ($localDebug);
		$curname = "";
	} else {
		$curname .= $token;
	}
    }
    $curname =~ s/^\s*//sg;
    $curname =~ s/\s*$//sg;
    if (length($curname)) {
	print "pushed \"$curname\"\n" if ($localDebug);
	push(@myargs, $curname);
    }

    return \@myargs;
}

sub ignore
{
    my $part = shift;
    my $ignorelistref = shift;
    my @ignorelist = @{$ignorelistref};
    my $phignorelistref = shift;
    my @perheaderignorelist = @{$phignorelistref};
    my $localDebug = 0;

    # if ($part =~ /AVAILABLE/) {
	# $localDebug = 1;
    # }

    foreach my $ignoretoken (@ignorelist) {
	$ignoretoken =~ s/^\s*//s;
	$ignoretoken =~ s/\s*$//s;
	if ($ignoretoken eq $part) {
	    print "$ignoretoken eq $part\n" if ($localDebug);
	    return 1;
	} else {
	    print "$ignoretoken ne $part\n" if ($localDebug);
	}

    }
    foreach my $ignoretoken (@perheaderignorelist) {
	$ignoretoken =~ s/^\s*//s;
	$ignoretoken =~ s/\s*$//s;
	if ($ignoretoken eq $part) {
	    print "$ignoretoken eq $part\n" if ($localDebug);
	    return 1;
	} else {
	    print "$ignoretoken ne $part\n" if ($localDebug);
	}

    }
    print "NO MATCH FOUND\n" if ($localDebug);
    return 0;
}

1;

