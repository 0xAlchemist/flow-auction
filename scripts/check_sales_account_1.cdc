// This script prints the NFTs that account 1 has for sale.

import VoteyAuction from 0xf3fcd2c1a78f5eee

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - demo-token.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - marketplace.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

pub fun main() {
    // get the public account object for account 1
    let account1 = getAccount(0x01cf0e2f2f715450)

    // find the public Sale Collection capability
    let account1AuctionRef = account1.getCapability(/public/NFTAuction)!
                                  .borrow<&VoteyAuction.AuctionCollection{VoteyAuction.AuctionPublic}>()
                                  ?? panic("unable to borrow a reference to the Auction collection for account 1")

    // Get the IDs from the auction queue
    let prices = account1AuctionRef.getAuctionQueuePrices()

    // Log the NFTs that are in the auction queue with their start prices
    log("Account 1 NFTs in the auction queue")
    log(prices)
}
