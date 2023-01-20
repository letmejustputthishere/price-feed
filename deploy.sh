#!/bin/bash
# create the canisters on the local network
dfx canister create ledger
dfx canister create minter

# safe the canister ids to variables
MINTERID="$(dfx canister id minter)"
echo $MINTERID
LEDGERID="$(dfx canister id ledger)"
echo $LEDGERID

# arguments to deploy the minter canister (check the minter.did file for explanations)
# the $LEDGERID is the canister id of the ledger canister tied to this ckBTC minter canister
echo "Step 2: deploying minter canister..."
dfx deploy minter --argument "(record {
    btc_network = variant { Regtest };
    ledger_id = principal \"$LEDGERID\";
    ecdsa_key_name = \"dfx_test_key\";
    retrieve_btc_min_amount = 5_000; 
    max_time_in_queue_nanos = 420_000_000_000
})" --mode=reinstall -y


# the principal id of the canister controller
PRINCIPAL="$(dfx identity get-principal)"
# arguments to deploy the ledger canister (check the ledger.did file)
# $MINTERID specifies the principal that is allowed to mint tokens on the ledger
# in our case that is the ckBTC minter canister
dfx deploy ledger --argument "(record {
    minting_account = record { owner = principal \"$MINTERID\" };
    transfer_fee = 0;
    token_symbol = \"ckBTC\";
    token_name = \"Token ckBTC\";
    metadata = vec {};
    initial_balances = vec {};
    archive_options = record {
        num_blocks_to_archive = 10_000;
        trigger_threshold = 20_000;
        cycles_for_archive_creation = opt 4_000_000_000_000;
        controller_id = principal \"$PRINCIPAL\";
    };
})"  --mode=reinstall -y

# this address is controlled by the ckBTC minter and unique for the current identity
# if we would make the call from a different identity, we would get a different address
echo "Get BTC address to sent BTC to, to mint ckBTC for current identity"
BTCADDRESS="$(dfx canister call minter get_btc_address '(record {subaccount=null;})')"
echo $BTCADDRESS

# here we mint BTC into the account returned by the get_btc_address call
# this way we put our BTC into the ckBTC minters control
read -p "Let the above address mint 400 blocks. Press [Enter] once done..."

# we check the ckBTC balance of our current identity, intially it should be 0
echo "Check the balance of the current identity before minting ckBTC"
dfx canister call ledger icrc1_balance_of "(record {owner= principal \"$PRINCIPAL\"})"

# now we inform the ckBTC minter that we want to mint ckBTC
# it checks the unique address (returned by get_btc_address) to see if it 
# actually received BTC and if so, it mints ckBTC for the current identity
echo "Call update_balance for current identity, to trigger minting of ckBTC from the ckBTC canister"
dfx canister call minter update_balance '(record {subaccount=null;})'

# we now check the ckBTC balance for our current identity again
# it should not be 0 anymore
echo "Check the balance of the current identity after minting ckBTC"
dfx canister call ledger icrc1_balance_of "(record {owner= principal \"$PRINCIPAL\"})"

# # next we get the unqique withdrawl address controlled by the ckBTC minter
# # for our current identity.
# # if we sent ckBTC to it, the ckBTC minter can burn the ckBTC and send the 
# # same amount of BTC to the address we specify in the retrieve_btc call
# echo "Get the ckBTC minters ledger account to send ckBTC to, to withdrawl BTC."
# WITHDRAWALADDRESS="$(dfx canister call minter get_withdrawal_account)"
# cleaned_output=$(echo $WITHDRAWALADDRESS | sed -re 's/^\(|, \)$//g')
# echo $cleaned_output

# # we transfer 100 ckBTC to the $WITHDRAWALADDRESS
# echo "Transfer ckBTC to the burning address of the ckBTC minter."
# dfx canister call ledger icrc1_transfer "(record {from=null; to=$cleaned_output; amount=10_000_000_000; fee=null; memo=null; created_at_time=null;})"

# # we check the ckBTC balance of our current identity again. should be 100 BTC less than before
# echo "Check the balance of the current identity after burning ckBTC"
# dfx canister call ledger icrc1_balance_of "(record {owner= principal \"$PRINCIPAL\"})"

# # we check the balance of the burning address, that should contain 100 ckBTC now
# echo "The balance of the ckBTC burning address"
# dfx canister call ledger icrc1_balance_of "($cleaned_output)"


# # We inform the ckBTC minter about our transaction, providing an Address to send the BTC to
# echo "Call retrieve_btc to withdrawl BTC from the ckBTC minter. This block has to be minted on the local network before the balance is updated"
# dfx canister call minter retrieve_btc '(record {fee = null; address="bcrt1qu9za0uzzd3kjjecgv7waqq0ynn8dl8l538q0xl"; amount=10000})'