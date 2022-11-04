function debug(string, error = false) {
  var quote = $('<blockquote>')
  if (error) {
    quote.addClass('red lighten-4')
  } else {
    quote.addClass('green lighten-4')
  }
  var d = new Date();
  quote.html(d.toISOString() + '&nbsp;&nbsp;' + string).appendTo('.debugContainer');
}

function showApplePayButtons() {
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
      debug('Apple Pay session can make payments')
      showApplePayButtons();
    } else {
      debug('Apple Pay session cannot make payments')
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
function purchaseEvent(paymentType) {
  $('.debugContainer').html('');
  debug('Purchase Event fired');

  var trx;

  const paymentRequest = {
    supportedNetworks: ['masterCard', 'visa'],
    merchantCapabilities: ['supports3DS'],

    countryCode: 'DK',
    currencyCode: 'DKK',

    total: { amount: '1.00' }
  };

  if (paymentType == 'non-series') {
    debug('Non-series payment');
    paymentRequest.total.label = 'Non-series purchase';
  } else if (paymentType == 'first-in-series') {
    debug('First-in-series payment');
    paymentRequest.total.label = 'First-in-series purchase';
    paymentRequest.recurringPaymentRequest = {
      paymentDescription: 'Subscription',
      regularBilling: {
        label: 'Subscription',
        amount: '1.00',
        paymentTiming: 'recurring',
        recurringPaymentStartDate: new Date(),
        recurringPaymentIntervalUnit: 'month',
        recurringPaymentIntervalCount: 3,
      },
      managementURL: 'https://applepaymerchant.clrhs.dk'
    };
  } else {
    debug('Invalid payment type');
    return;
  }

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
