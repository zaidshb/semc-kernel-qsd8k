#!/usr/bin/perl
#
# arch/arm/mach-msm/mkrpcsym.pl
#
# Generate the smd_rpc_sym.c symbol file for ONCRPC SMEM Logging
#
#
# Copyright (c) 2009, Code Aurora Forum. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of Code Aurora Forum nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# Alternatively, provided that this notice is retained in full, this software
# may be relicensed by the recipient under the terms of the GNU General Public
# License version 2 ("GPL") and only version 2, in which case the provisions of
# the GPL apply INSTEAD OF those given above.  If the recipient relicenses the
# software under the GPL, then the identification text in the MODULE_LICENSE
# macro must be changed to reflect "GPLv2" instead of "Dual BSD/GPL".  Once a
# recipient changes the license terms to the GPL, subsequent recipients shall
# not relicense under alternate licensing terms, including the BSD or dual
# BSD/GPL terms.  In addition, the following license statement immediately
# below and between the words START and END shall also then apply when this
# software is relicensed under the GPL:
#
# START
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 2 and only version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# END
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


use strict;
use POSIX;

my $base_fn = "smd_rpc_sym";
my %prog_table;
my ($in, $out) = @ARGV;
my $max_table_size = 1024;

my $copyright = <<"EOF";
/*
Copyright (c) 2009, Code Aurora Forum. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Code Aurora Forum nor
      the names of its contributors may be used to endorse or promote
      products derived from this software without specific prior written
      permission.

Alternatively, provided that this notice is retained in full, this software
may be relicensed by the recipient under the terms of the GNU General Public
License version 2 ("GPL") and only version 2, in which case the provisions of
the GPL apply INSTEAD OF those given above.  If the recipient relicenses the
software under the GPL, then the identification text in the MODULE_LICENSE
macro must be changed to reflect "GPLv2" instead of "Dual BSD/GPL".  Once a
recipient changes the license terms to the GPL, subsequent recipients shall
not relicense under alternate licensing terms, including the BSD or dual
BSD/GPL terms.  In addition, the following license statement immediately
below and between the words START and END shall also then apply when this
software is relicensed under the GPL:

START

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License version 2 and only version 2 as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

END

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
*/
EOF

sub smd_rpc_gen_files() {
	my $c_fp;
	my $h_fp;
	my @table;
	my $tbl_index;
	my $num_undefined=0;

	# Process the input hash table into an array
	# Any duplicate items will be combined, missing items will
	# become "UNKNOWN"  We end-up with a fully-qualified table
	# from 0 to n.

	$prog_table{"UNDEFINED"}{'name'}="UNDEFINED";
	$prog_table{"UNDEFINED"}{'prog'}=-1;
	my $hex_num = 0xFFFF;
	foreach my $api_prog (sort {$a cmp $b} keys %prog_table ) {
		$tbl_index = hex($api_prog) & hex("0000FFFF");
		if($prog_table{$api_prog}{'prog'} >= 0) {
			if($tbl_index < $max_table_size) {
				$table[$tbl_index]=$prog_table{$api_prog};
			} else {
				print "Skipping table item $tbl_index, larger ",
					"than max:$max_table_size \n";
			}
		}
	}
	for (my $i=0; $i<=$#table; $i++) {
		if (!exists $table[$i]) {
			$table[$i]=$prog_table{"UNDEFINED"};
		$num_undefined++;
		}
	}


	open($c_fp, ">", $out) or die  $!;
	print $c_fp $copyright;
	print $c_fp "\n\n\n";
	print $c_fp <<"EOF";
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/debugfs.h>
#include <linux/module.h>

struct sym {
	const char *str;
};

EOF

# Each API is named starts with "CB " to allow both the forward and
# callback names of the API to be returned from a common database.
# By convention, program names starting with 0x30 are forward APIS,
# API names starting with 0x31 are callback apis.
	print $c_fp "const char *smd_rpc_syms[] = {\n";

	for (my $i=0; $i<= $#table; $i++) {
		my $l = length($table[$i]{'name'});
		my $t = floor((45 - $l - 4)/8);
		print $c_fp "\t\"CB ".uc($table[$i]{'name'})."\",";
		if($table[$i]{'name'} ne "UNDEFINED") {
			for (my $i=0;$i<$t;$i++) {
				print $c_fp "\t";
			}
			print $c_fp "/*".$table[$i]{'prog'}."*/\n";
		} else {
			print $c_fp "\n";
		}
	}

	print $c_fp "};\n";
	print $c_fp <<"EOF";

static struct sym_tbl {
	const char **data;
	int size;
} tbl = { smd_rpc_syms, ARRAY_SIZE(smd_rpc_syms)};

const char *smd_rpc_get_sym(uint32_t val)
{
	int idx = val & 0xFFFF;
	if (idx < tbl.size) {
		if (val & 0x01000000)
			return tbl.data[idx];
		else
			return tbl.data[idx] + 3;
	}
	return 0;
}
EXPORT_SYMBOL(smd_rpc_get_sym);

EOF
	close $c_fp;
}

sub read_smd_rpc_table() {
	my $fp;
	my $line;
	open($fp, "<", $in) or die  "$! File:$in";
	while ($line = <$fp>) {
		chomp($line);
		if($line =~ /([^\s]+)\s+([\w]+)$/) {
			if(defined $prog_table{$1}) {
				print "Error entry already defined $1,",
				      " in $prog_table{$1}{name} \n";
			} else {
				$prog_table{$1}{'name'}=$2;
				$prog_table{$1}{'prog'}=$1;
			}
		} else {
			if($line =~ /\w/) {
				print "Error parsing error >>$line<< \n";
			}
		}
	}
	close $fp;
}

read_smd_rpc_table();
smd_rpc_gen_files();
