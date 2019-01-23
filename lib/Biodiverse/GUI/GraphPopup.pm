package Biodiverse::GUI::GraphPopup;

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use Carp;
use Gnome2::Canvas;

use Gtk2;

our $VERSION = '1.99_006';

use English qw { -no_match_vars };

use Biodiverse::GUI::PopupObject;
use Biodiverse::GUI::CanvasGraph;

use constant COLOUR_RED         => Gtk2::Gdk::Color->new(255*257, 0, 0);
use constant COLOUR_LILAC       => Gtk2::Gdk::Color->new(200, 200, 255);

sub add_graph {
    my $popup      = shift;
    my $output_ref = shift;
    my $list_name  = shift;
    my $element    = shift;
    my $popupobj   = shift;
    my $bounds_to_use = shift // warn 'no bounds!';
    
    say "Bounds for $list_name: " . join (' ', %$bounds_to_use{sort keys %$bounds_to_use});

    my $list_ref = $output_ref->get_list_ref (
        element => $element,
        list    => $list_name,
    );

    my $canvasobj = $popupobj->get_canvas;
    my $canvas    = $canvasobj ? $canvasobj : $popup->get_canvas;

    my $background
       = $popup->get_background
      || Biodiverse::GUI::CanvasGraph->new(
            canvas   => $canvas,
            popupobj => $popupobj,
        );

    if (my $primary = $background->get_primary) {
        $primary->destroy();
    }

    $background->add_primary_layer(
        graph_values => $list_ref,
        point_colour => COLOUR_LILAC,
        canvas       => $canvas,
        %$bounds_to_use,
    );

    $popup->set_background($background);
    $popup->set_primary($background->get_primary);
    $popup->set_secondary($background->get_secondary);
    $popup->set_list_ref($list_ref);


    $canvas->show();

    return;
}

sub add_secondary {
    my $self       = shift;
    my $output_ref = shift;
    my $list_name  = shift;
    my $element    = shift;
    my $popupobj   = shift;
    my $bounds_to_use = shift;

    my $secondary_element = $popupobj->get_secondary_element;

    return
      if !$popupobj->{force_replot}
      && defined $element
      && defined $secondary_element
      && $element eq $secondary_element;

    my $list_ref = $output_ref->get_list_ref (
        element => $element,
        list    => $list_name,
        autovivify => 0,
    );


    my $background = $popupobj->get_background;
    my $canvas     = $popupobj->get_canvas;

    #my $point_colour = Gtk2::Gdk::Color->new(255*257, 0, 0);
    #my $point_colour = Gtk2::Gdk::Color->parse('#7F7F7F');
    my $point_colour = 'red';

    # call graph update here if it exists.
    my $primary   = $background->get_primary;

    if ($primary) {
        my $secondary = $background->get_secondary;
        if ($secondary) {
            $secondary->destroy;
        }
        $secondary = $background->add_secondary_layer (
            graph_values => $list_ref,
            point_colour => $point_colour,
            canvas       => $canvas,
            %$bounds_to_use,
        );
        $secondary->raise_to_top();
        $secondary->show();
        $popupobj->set_secondary($secondary);
        $popupobj->set_secondary_element($element);
    }
}
