# AHDump
WoW Classic 1.13 Addon - Scan and write Auction House listed items into LUA file.

# Usage
* Place in your `Interface/AddOns` folder
* Open the Auction House
* Write `/ah`, wait until it finishs
* Write `/ah b` to buy next item for vendor profit, do it until all items were bought
* Logout or `/run ReloadUI()` to save data to LUA files

You'll then be able to access the AH contents in `WTF/Account/ACCOUNTNAME/SavedVariables/AHDump.lua` folder.

**AUCTION ROW**
 * itemId - [unique identifier](https://wowwiki.fandom.com/wiki/ItemString)
 * count - Number of items in the stack (number)
 * minBid - Minimum cost to bid on the item (in copper) (number)
 * minIncrement - Minimum bid increment to become the highest bidder on the item (in copper) (number)
 * buyoutPrice - Buyout price of the auction (in copper) (number)
 * bidAmount - Current highest bid on the item (in copper); 0 if no bids have been placed (number)
 * highestBidder - 1 if the player is currently the highest bidder; otherwise nil (1nil)
 * owner - Name of the character who placed the auction (string)
 * sold - 1 if the auction has sold (and payment is awaiting delivery; applies only to owner auctions); otherwise nil (number)

**ITEM ROW**
 * name - Name of the item (string)
 * quality - The quality (rarity) level of the item (number, itemQuality)
 * iLevel - Internal level of the item; (number)
 * reqLevel - Minimum character level required to use or equip the item (number)
 * class - Localized name of the item's class/type (as in the list returned by GetAuctionItemClasses()) (string)
 * subclass - Localized name of the item's subclass/subtype (as in the list returned by GetAuctionItemSubClasses()) (string)
 * maxStack - Maximum stack size for the item (i.e. largest number of items that can be held in a single bag slot) (number)
 * equipSlot - Non-localized token identifying the inventory type of the item (as in the list returned by GetAuctionItemInvTypes()); name of a global variable containing the localized name of the inventory type (string)
 * vendorPrice - Price an NPC vendor will pay to buy the item from the player. This value was added in patch 3.2. (number)
 
