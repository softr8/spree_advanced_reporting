// TODO this would look alot cleaner in coffeescript

$(function() {
	$('ul#show_data li').click(function() {
		$('ul#show_data li').not(this).removeClass('selected');
		$(this).addClass('selected');
		var id = 'div#' + $(this).attr('id') + '_data';
		$('div.advanced_reporting_data').not($(id)).hide();
		$(id).show(); 
	});

	if($('table.tablesorter tbody').length) {
		$('table.tablesorter').tablesorter();
		$('table.tablesorter').bind("sortEnd", function() {
			var section = $(this).parent().attr('id');
			var even = true;
			$.each($('div#' + section + ' table tr'), function(i, j) {
				$(j).removeClass('even').removeClass('odd');
				$(j).addClass(even ? 'even' : 'odd');
				even = !even;
			});
		});
	}

	if($('input#product_id').length > 0) {
		$('select#advanced_reporting_product_id').val($('input#product_id').val());
	}
	if($('input#taxon_id').length > 0) {
		$('select#advanced_reporting_taxon_id').val($('input#taxon_id').val());
	}
	$('div#advanced_report_search form').submit(function() {
		$('div#advanced_report_search form').attr('action', $('select#report').val());
	});

	$('select#report').change(function() {
		var value = $(this).val()
		$('div#advanced_report > form').action = value

		if(value.match(/\/count$/) || value.match(/\/top_products$/)) {
			$('select#advanced_reporting_product_id,select#advanced_reporting_taxon_id').val('');
			$('div#taxon_products').hide();
		} else {
			$('div#taxon_products').show();
		}
	}).trigger('change')
})
