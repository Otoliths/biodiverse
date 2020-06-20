#!/usr/bin/perl -w

#  Tests for basedata import
#  Need to add tests for the number of elements returned,
#  amongst the myriad of other things that a basedata object does.

use 5.010;
use strict;
use warnings;
use English qw { -no_match_vars };
use Data::Dumper;
use Path::Class;
use List::Util 1.45 qw /uniq/;
use Test::Lib;
use rlib;

use Data::Section::Simple qw(
    get_data_section
);

local $| = 1;

#use Test::More tests => 5;
use Test::Most;

use Biodiverse::BaseData;
use Biodiverse::ElementProperties;
use Biodiverse::TestHelpers qw /:basedata/;


use Devel::Symdump;
my $obj = Devel::Symdump->rnew(__PACKAGE__); 
my @test_subs = grep {$_ =~ 'main::test_'} $obj->functions();


exit main( @ARGV );

sub main {
    my @args  = @_;

    if (@args) {
        for my $name (@args) {
            die "No test method test_$name\n"
                if not my $func = (__PACKAGE__->can( 'test_' . $name ) || __PACKAGE__->can( $name ));
            $func->();
        }
        done_testing;
        return 0;
    }

    foreach my $sub (@test_subs) {
        no strict 'refs';
        $sub->();
    }

    done_testing;
    return 0;
}


sub test_reintegrate_after_separate_randomisations {
    #  use a small basedata for test speed purposes
    my %args = (
        x_spacing   => 1,
        y_spacing   => 1,
        CELL_SIZES  => [1, 1],
        x_max       => 5,
        y_max       => 5,
        x_min       => 1,
        y_min       => 1,
    );

    my $bd1 = get_basedata_object (%args);
    
    #  need some extra labels so the randomisations have something to do
    $bd1->add_element (group => '0.5:0.5', label => 'extra1');
    $bd1->add_element (group => '1.5:0.5', label => 'extra1');

    my $sp = $bd1->add_spatial_output (name => 'sp1');
    $sp->run_analysis (
        spatial_conditions => ['sp_self_only()', 'sp_circle(radius => 1)'],
        calculations => [
          qw /
            calc_endemism_central
            calc_endemism_central_lists
            calc_element_lists_used
          /
        ],
    );
    my $cl = $bd1->add_cluster_output (name => 'cl1');
    $cl->run_analysis (
        spatial_calculations => [
          qw /
            calc_endemism_central
            calc_endemism_central_lists
            calc_element_lists_used
          /
        ],
    );
    my $rg = $bd1->add_cluster_output (name => 'rg1', type => 'Biodiverse::RegionGrower');
    $rg->run_analysis (
        spatial_calculations => [
          qw /
            calc_endemism_central
            calc_endemism_central_lists
            calc_element_lists_used
          /
        ],
    );

    my $bd2 = $bd1->clone;
    my $bd3 = $bd1->clone;
    my $bd4 = $bd1->clone;  #  used lower down to check recursive reintegration
    my $bd5 = $bd1->clone;  #  used to check for different groups/labels
    
    $bd5->add_element (group => '0.5:0.5', label => 'blort');
    
    my $bd_base = $bd1->clone;

    my $prng_seed = 2345;
    my $i = 0;
    foreach my $bd ($bd1, $bd2, $bd3, $bd4, $bd5) { 
        $i %= 3;  #  max out at 3
        $i++;

        my $rand1 = $bd->add_randomisation_output (name => 'random1');
        my $rand2 = $bd->add_randomisation_output (name => 'random2');
        $prng_seed++;
        my %run_args = (
            function   => 'rand_csr_by_group',
            seed       => $prng_seed,
            build_randomised_trees => 1,
        );
        $rand1->run_analysis (
            %run_args,
            iterations => $i,
        );
        $prng_seed++;
        $rand2->run_analysis (
            %run_args,
            iterations => $i,
        );
    }

    isnt_deeply (
        $bd1->get_spatial_output_ref (name => 'sp1'),
        $bd2->get_spatial_output_ref (name => 'sp1'),
        'spatial results differ after randomisation, bd1 & bd2',
    );
    isnt_deeply (
        $bd1->get_spatial_output_ref (name => 'sp1'),
        $bd3->get_spatial_output_ref (name => 'sp1'),
        'spatial results differ after randomisation, bd1 & bd3',
    );
    isnt_deeply (
        $bd1->get_cluster_output_ref (name => 'cl1'),
        $bd2->get_cluster_output_ref (name => 'cl1'),
        'cluster results differ after randomisation, bd1 & bd2',
    );
    isnt_deeply (
        $bd1->get_cluster_output_ref (name => 'cl1'),
        $bd3->get_cluster_output_ref (name => 'cl1'),
        'cluster results differ after randomisation, bd1 & bd3',
    );
    isnt_deeply (
        $bd1->get_cluster_output_ref (name => 'rg1'),
        $bd2->get_cluster_output_ref (name => 'rg1'),
        'region grower differ after randomisation, bd1 & bd2',
    );
    isnt_deeply (
        $bd1->get_cluster_output_ref (name => 'rg1'),
        $bd3->get_cluster_output_ref (name => 'rg1'),
        'region grower results differ after randomisation, bd1 & bd3',
    );
    

    my $bd_orig;

    for my $bd_from ($bd2, $bd3) {
        #  we need the pre-integration values for checking
        $bd_orig = $bd1->clone;
        $bd1->reintegrate_after_parallel_randomisations (
            from => $bd_from,
        );
        check_randomisation_lists_incremented_correctly_spatial (
            orig   => $bd_orig->get_spatial_output_ref (name => 'sp1'),
            integr => $bd1->get_spatial_output_ref     (name => 'sp1'),
            from   => $bd_from->get_spatial_output_ref (name => 'sp1')
        );
        check_randomisation_lists_incremented_correctly_cluster (
            orig   => $bd_orig->get_cluster_output_ref (name => 'cl1'),
            integr => $bd1->get_cluster_output_ref     (name => 'cl1'),
            from   => $bd_from->get_cluster_output_ref (name => 'cl1')
        );
        check_randomisation_lists_incremented_correctly_cluster (
            orig   => $bd_orig->get_cluster_output_ref (name => 'rg1'),
            integr => $bd1->get_cluster_output_ref     (name => 'rg1'),
            from   => $bd_from->get_cluster_output_ref (name => 'rg1')
        );
    }

    _test_reintegrated_basedata_unchanged ($bd1, 'reintegrated correctly');
    
    #  now check that we don't double reintegrate
    $bd_orig = $bd1->clone;
    for my $bd_from ($bd2, $bd3) {
        eval {
            $bd1->reintegrate_after_parallel_randomisations (
                from => $bd_from,
            );
        };
        ok ($@, 'we threw an error');
        check_randomisation_integration_skipped (
            orig   => $bd_orig->get_spatial_output_ref (name => 'sp1'),
            integr => $bd1->get_spatial_output_ref (name => 'sp1'),
        );
    }

    _test_reintegrated_basedata_unchanged (
        $bd1,
        'no integration when already done',
    );

    #  now check that we don't double reintegrate a case like a&b&c with d&b&c
    $bd_orig = $bd1->clone;
    $bd4->reintegrate_after_parallel_randomisations (from => $bd2);
    $bd4->reintegrate_after_parallel_randomisations (from => $bd3);

    eval {
        $bd1->reintegrate_after_parallel_randomisations (
            from => $bd4,
        );
    };
    ok ($@, 'we threw an error');
    check_randomisation_integration_skipped (
        orig   => $bd_orig->get_spatial_output_ref (name => 'sp1'),
        integr => $bd1->get_spatial_output_ref (name => 'sp1'),
    );

    _test_reintegrated_basedata_unchanged (
        $bd1,
        'no integration when already done (embedded double)',
    );

    eval {
        $bd1->reintegrate_after_parallel_randomisations (
            from => $bd5,
        );
    };
    ok ($@, 'we threw an error for label/group mismatch');
    _test_reintegrated_basedata_unchanged ($bd1, 'no integration for group/label mismatch');

    
    return;
}

sub _test_reintegrated_basedata_unchanged {
    my ($bd1, $sub_name) = @_;

    $sub_name //= 'test_reintegrated_basedata_unchanged';

    my @names = sort {$a->get_name cmp $b->get_name} $bd1->get_randomisation_output_refs;
    
    subtest $sub_name => sub {
        foreach my $rand_ref (@names) {
            my $name = $rand_ref->get_name;
            is ($rand_ref->get_param('TOTAL_ITERATIONS'),
                6,
                "Total iterations is correct after reintegration ignored, $name",
            );
            my $prng_init_states = $rand_ref->get_prng_init_states_array;
            is (scalar @$prng_init_states,
                3,
                "Got 3 init states when reintegrations ignored, $name",
            );
            my $prng_end_states = $rand_ref->get_prng_end_states_array;
            is (scalar @$prng_end_states,
                3,
                "Got 3 end states when reintegrations ignored, $name",
            );
            my $a_ref = $rand_ref->get_prng_total_counts_array;
            is_deeply (
                $a_ref,
                [1, 2, 3],
                "got expected total iteration counts array when reintegrations ignored, $name",
            );
        }
    };

    return;
}

sub test_reintegration_updates_p_indices {
    #  use a small basedata for test speed purposes
    my %args = (
        x_spacing   => 1,
        y_spacing   => 1,
        CELL_SIZES  => [1, 1],
        x_max       => 5,
        y_max       => 5,
        x_min       => 1,
        y_min       => 1,
    );

    my $bd_base = get_basedata_object (%args);
    
    #  need some extra labels so the randomisations have something to do
    $bd_base->add_element (group => '0.5:0.5', label => 'extra1');
    $bd_base->add_element (group => '1.5:0.5', label => 'extra1');

    my $sp = $bd_base->add_spatial_output (name => 'analysis1');
    $sp->run_analysis (
        spatial_conditions => ['sp_self_only()'],
        calculations => [qw /calc_endemism_central/],
    );

    my $prng_seed = 234587654;
    
    my $check_name = 'rand_check_p';
    my @basedatas;
    for my $i (1 .. 5) {
        my $bdx = $bd_base->clone;
        my $randx = $bdx->add_randomisation_output (name => $check_name);
        $prng_seed++;
        $randx->run_analysis (
            function   => 'rand_structured',
            iterations => 9,
            seed       => $prng_seed,
        );
        push @basedatas, $bdx;
    }
    
    my $list_name = $check_name . '>>SPATIAL_RESULTS';


    my $bd_into = shift @basedatas;
    my $sp_integr = $bd_into->get_spatial_output_ref (name => 'analysis1');

    #  make sure some of the p scores are wrong so they get overridden 
    foreach my $group ($sp_integr->get_element_list) {
        my %l_args = (element => $group, list => $list_name);
        my $lr_integr = $sp_integr->get_list_ref (%l_args);
        foreach my $key (grep {$_ =~ /^P_/} keys %$lr_integr) {
            #say $lr_integr->{$key};
            $lr_integr->{$key} /= 2;
            #say $lr_integr->{$key};
        }
    }

    #  now integrate them
    foreach my $bdx (@basedatas) {
        $bd_into->reintegrate_after_parallel_randomisations (
            from => $bdx,
        );
    }
    
    
    subtest 'P_ scores updated after reintegration' => sub {
        my $gp_list = $bd_into->get_groups;
        foreach my $group (@$gp_list) {
            my %l_args = (element => $group, list => $list_name);
            my $lr_integr = $sp_integr->get_list_ref (%l_args);
            
            foreach my $key (sort grep {$_ =~ /P_/} keys %$lr_integr) {
                #no autovivification;
                my $index = substr $key, 1;
                is ($lr_integr->{$key},
                    $lr_integr->{"C$index"} / $lr_integr->{"Q$index"},
                    "Integrated = orig+from, $lr_integr->{$key}, $group, $list_name, $key",
                );
            }
        }
    };
}

sub check_randomisation_integration_skipped {
    my %args = @_;
    my ($sp_orig, $sp_integr) = @args{qw /orig integr/};

    my $test_name = 'randomisation lists incremented correctly when integration '
                  . 'should be skipped (i.e. no integration was done)';
    subtest $test_name => sub {
        my $gp_list = $sp_integr->get_element_list;
        my $list_names = $sp_integr->get_lists (element => $gp_list->[0]);
        my @rand_lists = grep {$_ !~ />>p_rank>>/ and $_ =~ />>/} @$list_names;
        foreach my $group (@$gp_list) {
            foreach my $list_name (@rand_lists) {
                my %l_args = (element => $group, list => $list_name);
                my $lr_orig   = $sp_orig->get_list_ref (%l_args);
                my $lr_integr = $sp_integr->get_list_ref (%l_args);
                is_deeply ($lr_integr, $lr_orig, "$group, $list_name");
            }
        }
    };
}

sub check_randomisation_lists_incremented_correctly_spatial {
    my %args = @_;
    my ($sp_orig, $sp_from, $sp_integr) = @args{qw /orig from integr/};

    my $object_name = $sp_integr->get_name;

    subtest "randomisation spatial lists incremented correctly, $object_name" => sub {
        my $gp_list = $sp_integr->get_element_list;
        my $list_names = $sp_integr->get_lists (element => $gp_list->[0]);
        my @rand_lists = grep {$_ =~ />>/ and $_ !~ />>\w+>>/} @$list_names;
        my @sig_lists  = grep {$_ =~ />>p_rank>>/}  @$list_names;
        my @z_lists    = grep {$_ =~ />>z_scores>>/} @$list_names;

        foreach my $group (@$gp_list) {
            foreach my $list_name (@rand_lists) {
                my %l_args = (element => $group, list => $list_name);
                my $lr_orig   = $sp_orig->get_list_ref (%l_args);
                my $lr_integr = $sp_integr->get_list_ref (%l_args);
                my $lr_from   = $sp_from->get_list_ref (%l_args);

                foreach my $key (sort keys %$lr_integr) {
                    no autovivification;
                    if ($key =~ /^P_/) {
                        my $index = substr $key, 1;
                        is ($lr_integr->{$key},
                            $lr_integr->{"C$index"} / $lr_integr->{"Q$index"},
                            "Integrated = orig+from, $lr_integr->{$key}, $group, $list_name, $key",
                        );
                    }
                    else {
                        is ($lr_integr->{$key},
                            ($lr_orig->{$key} // 0) + ($lr_from->{$key} // 0),
                            "Integrated = orig+from, $lr_integr->{$key}, $group, $list_name, $key",
                        );
                    }
                }
            }

            foreach my $sig_list_name (@sig_lists) {
                #  we only care if they are in the valid set
                my %l_args = (element => $group, list => $sig_list_name);
                my $lr_integr = $sp_integr->get_list_ref (%l_args);
                foreach my $key (sort keys %$lr_integr) {
                    my $value = $lr_integr->{$key};
                    if (defined $value) {
                        ok ($value < 0.05 || $value > 0.95,
                            "p-rank $value in valid interval ($key), $group",
                        );
                    }
                }
            }

            foreach my $z_list_name (@z_lists) {
                #  we only care if they are in the valid set
                my %l_args = (element => $group, list => $z_list_name);
                my $lr_integr = $sp_integr->get_list_ref (%l_args);
                foreach my $key (sort keys %$lr_integr) {
                    #my $value = $lr_integr->{$key};
                    #if (defined $value) {
                    #    ok ($value < 0.05 || $value > 0.95,
                    #        "z-score OK ($key), $group",
                    #    );
                    #}
                    ###  TO DO
                }
            }
        }
    };
}


sub check_randomisation_lists_incremented_correctly_cluster {
    my %args = @_;
    my ($cl_orig, $cl_from, $cl_integr) = @args{qw /orig from integr/};
    
    my $object_name = $cl_integr->get_name;

    subtest "randomisation cluster lists incremented correctly, $object_name" => sub {
        my $to_nodes   = $cl_integr->get_node_refs;
        my $list_names = $cl_integr->get_hash_list_names_across_nodes;
        my @rand_lists = grep {$_ =~ />>/ and $_ !~ />>\w+>>/} @$list_names;
        my @sig_lists  = grep {$_ =~ />>p_rank>>/} @$list_names;
        my @z_lists    = grep {$_ =~ />>z_scores>>/} @$list_names;
        
        my @rand_names = uniq (map {my $xx = $_; $xx =~ s/>>.+$//; $xx} @sig_lists);
        foreach my $to_node (sort {$a->get_name cmp $b->get_name} @$to_nodes) {
            my $node_name = $to_node->get_name;
            my $from_node = $cl_from->get_node_ref (node => $node_name);
            my $orig_node = $cl_orig->get_node_ref (node => $node_name);
            foreach my $list_name (@rand_lists) {
                my %l_args = (list => $list_name);
                my $lr_orig   = $orig_node->get_list_ref (%l_args);
                my $lr_integr = $to_node->get_list_ref (%l_args);
                my $lr_from   = $from_node->get_list_ref (%l_args);

                my $ok_count = 0;
                my $fail_msg = '';
                #  should refactor this - it duplicates the spatial variant
              BY_KEY:
                foreach my $key (sort keys %$lr_integr) {
                    #no autovivification;
                    my $exp;
                    if ($key =~ /^P_/) {
                        my $index = substr $key, 1;
                        $exp = $lr_integr->{"C$index"} / $lr_integr->{"Q$index"};
                    }
                    else {
                        $exp = ($lr_orig->{$key} // 0) + ($lr_from->{$key} // 0);
                    }
                    if ($lr_integr->{$key} ne $exp) {
                        $fail_msg = "FAILED: Integrated = orig+from, "
                          . "$lr_integr->{$key}, $node_name, $list_name, $key";
                        last BY_KEY;
                    }
                }
                ok (!$fail_msg, "reintegrated $list_name for $node_name");
            }

            foreach my $sig_list_name (@sig_lists) {
                #  we only care if they are in the valid set
                my %l_args = (list => $sig_list_name);
                my $lr_integr = $to_node->get_list_ref (%l_args);
                foreach my $key (sort keys %$lr_integr) {
                    my $value = $lr_integr->{$key};
                    if (defined $value) {
                        ok ($value < 0.05 || $value > 0.95,
                            "p-rank $value in valid interval ($key), $node_name",
                        );
                    }
                }
            }
            foreach my $z_list_name (@sig_lists) {
                #  we only care if they are in the valid set
                #my %l_args = (list => $sig_list_name);
                #my $lr_integr = $to_node->get_list_ref (%l_args);
                #foreach my $key (sort keys %$lr_integr) {
                #    my $value = $lr_integr->{$key};
                #    if (defined $value) {
                #        ok ($value < 0.05 || $value > 0.95,
                #            "p-rank $value in valid interval ($key), $node_name",
                #        );
                #    }
                #}
            }


            #  now the data and stats
            foreach my $rand_name (@rand_names) {
                foreach my $suffix (qw/_DATA _ID_LDIFFS/) {
                    my $data_list_name = $rand_name . $suffix;
                    my $to_data_list   = $to_node->get_list_ref (list => $data_list_name);
                    my $from_data_list = $from_node->get_list_ref (list => $data_list_name);
                    my $orig_data_list = $orig_node->get_list_ref (list => $data_list_name);
                    is_deeply (
                        $to_data_list,
                        [@$orig_data_list, @$from_data_list],
                        "expected data list for $node_name, $data_list_name",
                    );
                }
                #  stats are more difficult - check the mean for now
                my $stats_list_name = $rand_name;
                my $to_stats   = $to_node->get_list_ref (list => $stats_list_name);
                my $from_stats = $from_node->get_list_ref (list => $stats_list_name);
                my $orig_stats = $orig_node->get_list_ref (list => $stats_list_name);
                #  avoid precision issues
                my $got = sprintf "%.10f", $to_stats->{MEAN};
                my $sum = $from_stats->{MEAN} * $from_stats->{COMPARISONS}
                        + $orig_stats->{MEAN} * $orig_stats->{COMPARISONS};
                my $expected = sprintf "%.10f", $sum / ($orig_stats->{COMPARISONS} + $from_stats->{COMPARISONS});
                is ($got, $expected, "got expected mean for $object_name: $node_name, $stats_list_name");
            }
        }
    };
}

