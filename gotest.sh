#!/bin/bash
#
#
./mongodrop.sh
#
# mix clean
# mix compile --force
# mix test test/cqrs/cancel_auction_command_test.exs --trace
#
# mix test test/cqrs/cqrs_user_test.exs --seed 0 --trace
# mix test --seed 0 --trace
# mix test test/cqrs/variable_price_standard_test.exs --only one --seed 0 --trace
mix test test/cqrs/cqrs_auction_test.exs --only one --seed 0 --trace
