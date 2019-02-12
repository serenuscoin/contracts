# @title Serenus Coin Oracle contract
# @notice Gets a midprice on-chain from Uniswap ETH/Dai, Uniswap ETH/USDC and Kyber ETH/TUSD
# @notice Source code found at https://github.com/serenuscoin
# @notice Use at your own risk
# @dev Compiled with Vyper 0.1.0b8

# @dev Reads balances from the mainnet MakerDAO Dai contract
contract Dai:
    def balanceOf(_address: address) -> uint256: constant

contract USDC:
    def balanceOf(_address: address) -> uint256: constant

contract Kyber:
    def getExpectedRate(_src: address, _dest: address, _srcQty: uint256) -> (uint256, uint256): constant

owner: public(address)                 # Owner

daiContract: Dai                       # Dai ERC20 address
usdcContract: USDC                     # USDC ERC20 address
uniswap_ethdai_pool: public(address)   # Uniswap's ETH/Dai pool
uniswap_ethusdc_pool: public(address)  # Uniswap's ETH/USDC pool

kybernetwork: Kyber                    # Kyber Network address
kyberether: public(address)
kybertusd: public(address)

# @notice Sets up addresses for the Dai ERC20 and the Uniswap pool for ETH/Dai
@public
def __init__():
    self.owner = msg.sender
    self.uniswap_ethdai_pool = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14
    self.daiContract = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359
    self.uniswap_ethusdc_pool = 0x97deC872013f6B5fB443861090ad931542878126
    self.usdcContract = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48

    self.kybernetwork = 0x9ae49C0d7F8F9EF4B864e004FE86Ac8294E20950
    self.kyberether = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    self.kybertusd = 0x8dd5fbCe2F6a956C3022bA3663759011Dd51e73E
    
@public
def liquidate():
    assert msg.sender == self.owner
    selfdestruct(self.owner)

@public
def changeOwner(_address: address):
    assert msg.sender == self.owner
    self.owner = _address
    
@public
def setUniswapETHDAIPool(_address: address):
    assert msg.sender == self.owner
    self.uniswap_ethdai_pool = _address

@public
def setDaiContract(_address: address):
    assert msg.sender == self.owner
    self.daiContract = _address

@public
def setUniswapETHUSDCPool(_address: address):
    assert msg.sender == self.owner
    self.uniswap_ethusdc_pool = _address

@public
def setUSDCContract(_address: address):
    assert msg.sender == self.owner
    self.usdcContract = _address

@public
def setKyberNetwork(_address: address):
    assert msg.sender == self.owner
    self.kybernetwork = _address

@public
def setKyberEther(_address: address):
    assert msg.sender == self.owner
    self.kyberether = _address

@public
def setKyberTUSD(_address: address):
    assert msg.sender == self.owner
    self.kybertusd = _address

# @notice Reads instantaneous midprice for ETH/stablecoin
# @dev Source can be made more efficient but at the cost of readability
# @return A price as an integer to the nearest cent
@public
def read() -> uint256:
    ethdai_balance: uint256(wei) = self.uniswap_ethdai_pool.balance
    dai_balance: uint256 = self.daiContract.balanceOf(self.uniswap_ethdai_pool)

    ethusdc_balance: uint256(wei) = self.uniswap_ethusdc_pool.balance
    usdc_balance: uint256 = self.usdcContract.balanceOf(self.uniswap_ethusdc_pool)
    
    ethdai: uint256 = (dai_balance * 100) / as_unitless_number(ethdai_balance)              # integer in cents; dai and eth are both expressed in 10**18 units
    ethusdc: uint256 = (usdc_balance * 100 * 10**12) / as_unitless_number(ethusdc_balance)  # integer in cents; usdc is expressed in 10**6 units

    ethkyber: uint256
    slippage: uint256
    (ethkyber, slippage) = self.kybernetwork.getExpectedRate(self.kyberether, self.kybertusd, 5*10**17)

    usdckyber: uint256
    (usdckyber, slippage) = self.kybernetwork.getExpectedRate(self.kybertusd, self.kyberether, ethkyber/2)

    ethtusd: uint256 = (10**20/usdckyber + ethkyber/10**16) / 2                             # integer in cents; average rate going back and forth

    return (ethdai + ethusdc + ethtusd) / 3
