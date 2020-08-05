// This transaction creates a new Auction Collection object,
// lists all NFTs for auction, puts it in account storage,
// and creates a public capability to the auction so that 
// others can bid on the tokens.

// Signer - Account 1 - 0x01cf0e2f2f715450

import NonFungibleToken from 0xe03daebed8ca0615
import FungibleToken from 0xee82856bf20e2aa6
import DemoToken from 0x01cf0e2f2f715450
import VoteyAuction from 0xf3fcd2c1a78f5eee

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - demo-token.cdc
// Acct 2 - 0x179b6b1cb6755e31 - rocks.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - votey-auction.cdc
// Acct 4 - 0xe03daebed8ca0615 - onflow/NonFungibleToken.cdc

transaction {
    prepare(account: AuthAccount) {

        let bidVault <- DemoToken.createEmptyVault()

        // borrow a reference to the signer's Vault
        let receiver = account.borrow<&{FungibleToken.Receiver}>(from: /storage/DemoTokenVault)
                              ?? panic("Unable to borrow a reference to the owner's vault")

        // borrow a reference to the NFT collection in storage
        let collectionRef = account.borrow<&NonFungibleToken.Collection>(from: /storage/RockCollection) 
                              ?? panic("Unable to borrow a reference to the NFT collection")

        // create a new sale object     
        // initializing it with the reference to the owner's Vault
        let auction <- VoteyAuction.createAuctionCollection(
            minimumBidIncrement: UFix64(5),
            auctionLengthInBlocks: UInt64(30),
            ownerVault: receiver,
            ownerNFTCollection: collectionRef,
            bidVault: <-bidVault
        )

        let collectionIDs = collectionRef.getIDs()

        for id in collectionIDs {
            // withdraw the NFT from the collection that you want to sell
            // and move it into the transaction's context
            let NFT <- collectionRef.withdraw(withdrawID: id)

            // list the token for sale by moving it into the sale resource
            auction.addTokenToAuctionQueue(token: <-NFT, startPrice: UFix64(10))
        }

        // store the sale resource in the account for storage
        account.save(<-auction, to: /storage/NFTAuction)

        // create a public capability to the sale so that others
        // can call it's methods
        account.link<&VoteyAuction.AuctionCollection{VoteyAuction.AuctionPublic}>(
            /public/NFTAuction,
            target: /storage/NFTAuction
        )

        log("Auction created for account 1. Listed NFT ids[1-10] for start price of 10 DemoTokens each.")
    }
}
 