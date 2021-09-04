# Leveraged Vault for Loan Saver Submission

This submission diverges somewhat from the Challenge Description however we believe it acheives the same outcome while having some other additional features that will be incredibly useful for users.

Simliar to RoboVault's existing vaults which utilise CREAM as a lender for our single asset yield strategies our leveraged coin MVP vaults allow users to deposit assets into vaults. Following the archictecture of Yearn assets within the vault are then deployed to a strategy. For the leverage coin MVP / Loan Saver this would involve using one asset as collateral and then borrowing a secondary asset the vault can then conduct additional loops trading the borrowed asset for the vault's base asset to acheive it's desired leverage level.

These vaults would then be monitored by external keepers constantly checking the collateral ratio within the vault to ensure there is no liquidation event. In the case that the collateral ratio goes above some threshold close to liquidation some collateral can be removed then swapped for the asset which the vault has borrowed to reduce the collateral ratio. Additionally the if the vaults collateral ratio falls below some threshold level the keeper can again rebalance the vault back to a desired leverage level by borrowing additional assets & then swapping for the vaults base asset.

This archicture means users can deposit assets into a vault following some desired leverage level while having keepers constantly managing assets ensuring over the long term their positions will not be liquidated. This archicture of vaults with specific levels of leverage can be implemented as a leveraged similiar to binanace 3x leverage coins which could be traded on a AMM. One final benefit of having assets being pooled in a single vault leading to significant gas savings while also being flexible enoug

The front end allowing users to enter these vaults would follow RoboVaults existing vaults : https://www.robo-vault.com/


# Contracts 
The core strategy & rebalancing mechanics can be found in token.sol including inputs for target collateral ratio, number of loops for leverage and logic behind rebalancing in order to save loans from liquidation (rebalanceCollateral) 

# Deployment & Managing Position

To deploy contract deposit funds & deploy to strategy run the following in Brownie (for vault which shorts FTM vs USDC) 

brownie compile
brownie console --network FTM

accounts.load("dev") 
amt = 5000

vault = leverageTest.deploy({"from": accounts[0]})

usdc = ERC20.at('0x04068DA6C83AFCFA0e13ba15A6696662335D5B75')

usdc.approve(vault, amt,{'from':accounts[0]})

vault.deposit(amt,{'from':accounts[0]}) 

vault.deployStrat({'from':accounts[0]}) 

vault.calcCollateral() 

vault.rebalanceCollateral()

vaule.calcCollateral() 

vault.undeployFromStrat(2500, {'from' : accounts[0]})

# Additional References 

High Level Diagram : https://github.com/RoboVault/leverage-tokens/blob/master/CREAM%20LoanSaver.pdf
Vault Strategy : https://docs.robo-vault.com/robovault/lend-hedge-farming
