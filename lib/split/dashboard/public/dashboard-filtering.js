$(function() {
  $('#filter').on('keyup', function() {
    $input = $(this);

    if ($input.val() === '') {
      $('tr.experiment').show();
      return false;
    }

    $('tr.experiment').hide();
    selector = 'tr.experiment[data-name*="' + $input.val() + '"]';
    $(selector).show();
  });

  $('#clear-filter').on('click', function() {
    $('#filter').val('');
    $('tr.experiment').show();
    $('#toggle-active').val('Hide active');
    $('#toggle-completed').val('Hide completed');
  });

  $('#toggle-active').on('click', function() {
    $button = $(this);
    if ($button.val() === 'Hide active') {
      $button.val('Show active');
    } else {
      $button.val('Hide active');
    }

    $('div.experiment[data-complete="false"]').toggle();
  });

  $('#toggle-completed').on('click', function() {
    $button = $(this);
    if ($button.val() === 'Hide completed') {
      $button.val('Show completed');
    } else {
      $button.val('Hide completed');
    }

    $('div.experiment[data-complete="true"]').toggle();
  });
});
