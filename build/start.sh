#!/bin/bash

# Configuration

TEMPLATE_FILE=public/index.template.js
OUTPUT_FILE=public/index.js

NON_SERIES_DETAILS=$(cat <<-END
    total: { label: 'Test Purchase', amount: '1.00', },
END
)

FIRST_IN_SERIES_DETAILS=$(cat <<-END
    recurringPaymentRequest: {
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
    },

    total: { label: 'Test first-in-series', amount: '1.00' },
END
)

# Preprocessing

echo 'Do you wish to serve a page for creating a non-series payment (N) or'
echo 'a first-in-series payment (F)? N is default.'
read answer

LINE_NUMBER=$(
  grep -n PAYMENT_REQUEST_DETAILS_TO_BE_INSERTED_HERE "$TEMPLATE_FILE" \
  | cut -d : -f 1
)

head -n $(($LINE_NUMBER-1)) "$TEMPLATE_FILE" > "$OUTPUT_FILE"

if [ "$answer" = "f" -o "$answer" = "F" ]; then
  echo "$FIRST_IN_SERIES_DETAILS" >> "$OUTPUT_FILE"
else
  echo "$NON_SERIES_DETAILS" >> "$OUTPUT_FILE"
fi

TOTAL_LINES=$(wc -l "$TEMPLATE_FILE" | cut -d ' ' -f 1)

tail -n $(($TOTAL_LINES-$LINE_NUMBER)) "$TEMPLATE_FILE" >> "$OUTPUT_FILE"

# Exec Puma

exec bundle exec puma --config config/puma.rb
