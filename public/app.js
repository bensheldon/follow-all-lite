$( function() {
  $('form#follow button[type=submit]').click(function(e) {
    $(this).find('i').removeClass('icon-heart').addClass('icon-refresh icon-spin')
  });
});