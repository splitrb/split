$(function() {
  $('#filter').on('keyup', function() {
    $input = $(this);

    if ($input.val() == '') {
      $('div.experiment').show();
      return false;
    }

    $('div.experiment').hide();
    selector = 'div.experiment[data-name*="' + $input.val() + '"]';
    $(selector).show();
  });

  $('#clear-filter').on('click', function() {
    $('#filter').val('');
    $('div.experiment').show();
  });
});
