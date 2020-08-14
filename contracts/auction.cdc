// VoteyAuction.cdc
//
// The VoteyAuction contract is an experimental implementation of an NFT Auction on Flow.
//
// This contract allows users to put their NFTs up for sale. Other users
// can purchase these NFTs with fungible tokens.
//
import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0x01cf0e2f2f715450
import DemoToken from 0x179b6b1cb6755e31

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - onflow/NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - demo-token.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - rocks.cdc
// Acct 4 - 0xe03daebed8ca0615 - auction.cdc
//

pub contract VoteyAuction {

    pub var totalAuctions: UInt64

    // Events
    pub event NewAuctionCollectionCreated(minimumBidIncrement: UFix64, auctionLengthInBlocks: UInt64)
    pub event TokenAddedToAuctionItems(tokenID: UInt64, startPrice: UFix64)
    pub event TokenStartPriceUpdated(tokenID: UInt64, newPrice: UFix64)
    pub event NewBid(tokenID: UInt64, bidPrice: UFix64)
    pub event AuctionSettled(tokenID: UInt64, price: UFix64)


    pub struct Bid {
        pub let nftCollection: Capability<&{NonFungibleToken.CollectionPublic}>
        pub let paybackVault: Capability<&{FungibleToken.Receiver}>

        init(
            nftCollection: Capability<&{NonFungibleToken.CollectionPublic}>,
            paybackVault: Capability<&{FungibleToken.Receiver}>
        ) {
            self.nftCollection=nftCollection
            self.paybackVault=paybackVault
        }

    }
    pub resource AuctionItem {

        pub let items: @{UInt64:NonFungibleToken.NFT}
        pub let escrow: @FungibleToken.Vault

        // Auction Settings
        pub let minimumBidIncrement: UFix64
        pub let auctionLengthInBlocks: UInt64

        pub(set) var currentBid: Bid?

        // Auction State
        pub(set) var startPrice: UFix64
        pub(set) var currentPrice: UFix64
        pub(set) var auctionStartBlock: UInt64

        // Owner's Receiver Capabilities
        pub let ownerCollectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
        pub let ownerVaultCap: Capability<&{FungibleToken.Receiver}>

        init(
            NFT: @NonFungibleToken.NFT,
            minimumBidIncrement: UFix64,
            auctionStartBlock: UInt64,
            auctionLengthInBlocks: UInt64,
            startPrice: UFix64,
            ownerCollectionCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            ownerVaultCap: Capability<&{FungibleToken.Receiver}>
        ) {
            self.items <- { UInt64(1) : <- NFT}
            self.escrow <- DemoToken.createEmptyVault()
            self.auctionStartBlock=getCurrentBlock().height
            self.auctionLengthInBlocks=auctionLengthInBlocks
            self.startPrice=startPrice
            self.ownerCollectionCap=ownerCollectionCap
            self.ownerVaultCap=ownerVaultCap
            self.currentPrice=startPrice
            self.minimumBidIncrement=minimumBidIncrement
            self.currentBid= nil

        }

        pub fun isAuctionExpired() : Bool {

             let auctionLength = self.auctionLengthInBlocks
            let startBlock = self.auctionStartBlock 
            let currentBlock = getCurrentBlock()
            
            if currentBlock.height - startBlock > auctionLength {
                return true
            } else {
                return false
            }
        }

        pub fun depositBidTokens(vault: @FungibleToken.Vault) {
            self.escrow.deposit(from: <-vault)
        }

        pub fun settleAuction() {

            // check if the auction has expired
            if self.isAuctionExpired() == false {
                log("Auction has not completed yet")
                return
            }
                
            // return if there are no bids to settle
            if self.currentPrice == self.startPrice {
                self.returnAuctionItemToOwner()
                log("No bids. Nothing to settle")
                return
            } 

            self.exchangeTokens()
            // todo just mark it as settled
        }

        pub fun withdrawNFT(): @NonFungibleToken.NFT {
            return <- self.items.remove(key:1)!
        }

        pub fun exchangeTokens() {
             if let bid= self.currentBid {
                //send the NFT to the bidders collection
                var nftCap= bid.nftCollection  
                log(nftCap)
                log("Capability<&{NonFungibleToken.CollectionPublic}> is the type of the capability logged above")
                var check= nftCap.check()
                log("does check() on this capability work?")
                log(check)
                var collectionPublic=nftCap.borrow()
                log("what is the result after borrow?")
                log(collectionPublic)
                //TODO: Why is that nil
                /* 
                collectionPublic.deposit(token: <- itemRef.withdrawNFT())

                //withdraw the escrowed money and send it to the ower
                //TODO: Marketplace cut, artist cut?
                let escrowTokens <- itemRef.escrow.withdraw(amount: itemRef.escrow.balance)
                let ownerVaultRef = itemRef.ownerVaultCap.borrow()!
                ownerVaultRef.deposit(from:<-escrowTokens)

                emit AuctionSettled(tokenID: id, price: itemRef.currentPrice)
                */

            }
        }
        access(contract) fun returnOwnerNFT(token: @NonFungibleToken.NFT) {
            // borrow a reference to the owner's NFT receiver
            let NFTReceiver = self.ownerCollectionCap.borrow()!

            // deposit the token into the owner's collection
            NFTReceiver.deposit(token: <-token)
        }

        access(contract) fun releaseBidderTokens() {
            pre {
                self.currentBid?.nftCollection != nil: "There is no recipient to release the tokens to"
            }

            // withdraw the entire token balance from escrow
            let bidTokens <- self.escrow.withdraw(amount: self.escrow.balance)

            // borrow a reference to the bidder's Vault receiver
            let vaultRef = self.currentBid!.paybackVault.borrow()
            
            // return the bidTokens to the bidder's Vault
            vaultRef!.deposit(from:<-bidTokens)
        }

         pub fun returnAuctionItemToOwner() {
            
            let ownerCollectionRef = self.ownerCollectionCap.borrow() ?? panic("Could not borrow ownerCollectionCap")
            
            // release the bidder's tokens
            self.releaseBidderTokens()

            // withdraw the NFT from the auction collection
            let NFT <-self.withdrawNFT()
            
            // deposit the NFT into the owner's collection
            ownerCollectionRef.deposit(token:<- NFT)

            // clear the NFT's meta data
        }

        pub fun bid(bidTokens: @FungibleToken.Vault, vaultCap: Capability<&{FungibleToken.Receiver}>, collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>) {

            if bidTokens.balance < self.minimumBidIncrement {
                panic("bid amount be larger than minimum bid increment")
            }
            
            if self.currentBid != nil {
                self.releaseBidderTokens()
            }

            // Update the auction item
            self.depositBidTokens(vault: <-bidTokens)
            self.currentBid=Bid(
                nftCollection:collectionCap,
                paybackVault:vaultCap
            )
            self.currentPrice= self.escrow.balance

        }

        destroy() {
            self.returnOwnerNFT(token: <-self.withdrawNFT())
            self.releaseBidderTokens()
            destroy self.escrow
            destroy self.items
        }
    }

    pub resource interface AuctionPublic {
        pub fun getAuctionPrices(): {UInt64: UFix64}
        pub fun placeBid(
            id: UInt64, 
            bidTokens: @FungibleToken.Vault, 
            vaultCap: Capability<&{FungibleToken.Receiver}>, 
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
        )
    }

    pub resource AuctionCollection: AuctionPublic {

        // Auction Items
        pub let auctionItems: @{UInt64: AuctionItem}
        
        pub let marketplaceVault: Capability<&{FungibleToken.Receiver}>

        init(
            marketplaceVault: Capability<&{FungibleToken.Receiver}>
        ) {
            self.marketplaceVault=marketplaceVault
            self.auctionItems <- {}
        }

        // addTokenToauctionItems adds an NFT to the auction items and sets the meta data
        // for the auction item
        pub fun addTokenToAuctionItems(token: @NonFungibleToken.NFT, minimumBidIncrement: UFix64, auctionLengthInBlocks: UInt64, startPrice: UFix64, collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>, vaultCap: Capability<&{FungibleToken.Receiver}>) {
             VoteyAuction.totalAuctions = VoteyAuction.totalAuctions + UInt64(1)
             var id=VoteyAuction.totalAuctions 
 
            // create a new auction items resource container
            let item <- create AuctionItem(
                NFT: <-token,
                minimumBidIncrement: minimumBidIncrement,
                auctionStartBlock: getCurrentBlock().height,
                auctionLengthInBlocks: auctionLengthInBlocks,
                startPrice: startPrice,
                ownerCollectionCap: collectionCap,
                ownerVaultCap: vaultCap
            )

            // update the auction items dictionary with the new resources
            let oldItem <- self.auctionItems[id] <- item
            destroy oldItem

            emit TokenAddedToAuctionItems(tokenID: id, startPrice: startPrice)
        }

        // getAuctionPrices returns a dictionary of available NFT IDs with their current price
        pub fun getAuctionPrices(): {UInt64: UFix64} {
            pre {
                self.auctionItems.keys.length > 0: "There are no auction items"
            }

            let priceList: {UInt64: UFix64} = {}

            for id in self.auctionItems.keys {
                let itemRef = &self.auctionItems[id] as? &AuctionItem
                priceList[id] = itemRef.currentPrice
            }
            
            return priceList
        }

        // settleAuction sends the auction item to the highest bidder
        // and deposits the FungibleTokens into the auction owner's account
        pub fun settleAuction(_ id: UInt64) {
            let itemRef = &self.auctionItems[id] as &AuctionItem
            itemRef.settleAuction()

        }

        // placeBid sends the bidder's tokens to the bid vault and updates the
        // currentPrice of the current auction item
        pub fun placeBid(id: UInt64, bidTokens: @FungibleToken.Vault, vaultCap: Capability<&{FungibleToken.Receiver}>, collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>) 
            {
            pre {
                self.auctionItems[id] != nil:
                    "NFT doesn't exist"
            }

            // Get the auction item resources
            let itemRef = &self.auctionItems[id] as &AuctionItem

            itemRef.bid(bidTokens: <- bidTokens, vaultCap:  vaultCap, collectionCap: collectionCap)
            
            emit NewBid(tokenID: id, bidPrice: itemRef.currentPrice)
        }

        destroy() {
            // destroy the empty resources
            destroy self.auctionItems
        }
    }

    // createAuctionCollection returns a new AuctionCollection resource to the caller
    pub fun createAuctionCollection(
        marketplaceVault: Capability<&{FungibleToken.Receiver}>,
    ): @AuctionCollection {

        let auctionCollection <- create AuctionCollection(
            marketplaceVault: marketplaceVault
        )

        return <- auctionCollection
    }

    init() {
        self.totalAuctions = UInt64(0)
    }   
}
 