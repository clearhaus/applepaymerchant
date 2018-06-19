function debug(string, error = false) {
  var quote = $('<blockquote>')
  if (error) {
    quote.addClass('red lighten-4')
  } else {
    quote.addClass('green lighten-4')
  }
  quote.html(string).appendTo('.debugContainer');
}

function showApplePayButton() {
    HTMLCollection.prototype[Symbol.iterator] = Array.prototype[Symbol.iterator];
    const buttons = document.getElementsByClassName("apple-pay-button");
    for (let button of buttons) {
        button.className += " visible";
    }
}

// Fire up the javascript frontend
document.addEventListener('DOMContentLoaded', () => {
  debug('DOM content loaded');
  if (window.ApplePaySession) {
    if (ApplePaySession.canMakePayments) {
      showApplePayButton();
    }
  }
});

function newestSupportedApplePayVersion() {
	if (ApplePaySession.supportsVersion(3)) {
    return 3;
	} else if (ApplePaySession.supportsVersion(2)) {
    return 2;
  } else {
    return 1;
  }
}

// When Apple Pay button is clicked.
function purchaseEvent() {
  $('.debugContainer').html('');
  debug('Purchase Event fired');

  var trx;

  const paymentRequest = {
    supportedNetworks:['masterCard', 'visa'],
    merchantCapabilities: [ "supports3DS" ],

    countryCode: 'DK',
    currencyCode: 'DKK',

    total: { label: 'Test Purchase', amount: '1.00', },
  };

  var session;
  try {
    // https://developer.apple.com/documentation/apple_pay_on_the_web/applepaysession/2320659-applepaysession
    session = new ApplePaySession(newestSupportedApplePayVersion(), paymentRequest);
  } catch (e) {
    debug("Unable to create session: " + e.message, true);
    return
  }

  debug('ApplePaySession created');

	// https://developer.apple.com/documentation/apple_pay_on_the_web/apple_pay_js_api/providing_merchant_validation
  session.onvalidatemerchant = function(ev) {
    trx = $.post({
      url: '/validatemerchant',
      data: {'validationURL':  encodeURIComponent(ev.validationURL)},
      success: (data) => {
        debug('ValidateMerchant call succeeded');
        //https://developer.apple.com/documentation/apple_pay_on_the_web/applepaysession/1778015-completemerchantvalidation
        session.completeMerchantValidation(data);
      },
      error: (xhr, textStatus) => {
        debug('Unable to validate merchant: Server responded ' + xhr.status +
        '<br/>Response:<br/>' + xhr.responseText, true);
      }
    });
  };

  //https://developer.apple.com/documentation/apple_pay_on_the_web/applepaysession/1778020-onpaymentauthorized
  session.onpaymentauthorized = function(event) {
    debug("Payment was authorized")
    payment = event.payment;

    trx = $.post({
      url: '/completesession',
      data: JSON.stringify(payment),
      contentType: 'application/json',
      processData: false,
      success: (data) => {
        session.completePayment(ApplePaySession.STATUS_SUCCESS);
        debug("Purchase was completed");
      },
      error: (xhr) => {
        session.completePayment(ApplePaySession.STATUS_FAILURE);
        debug("Error completing session: HTTPResponse " + xhr.status, true);
      }
    });
  };

  session.oncancel = function(event) {
    debug("ApplePaySession was cancelled", true)
    if (trx && trx.readyState != 4) {
      trx.abort("Payment Cancelled");
    }
  }

  session.begin();
}
