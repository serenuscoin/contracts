# @title Serenus Coin Governor contract
# @notice Sets global governance parameters
# @notice No Issuer contract can mint/burn unless up-to-date
# @notice Source code found at https://github.com/serenuscoin
# @notice Use at your own risk
# @dev Compiled with Vyper 0.1.0b5

owner: public(address)

nonce: public(int128)
issuer_fees: public(uint256)
minimum_collateral_ratio: public(uint256)
liquidity_multiplier: public(uint256)
erc20_serenus: public(address)
oracle: public(address)

@public
def __init__():
    self.owner = msg.sender
    self.nonce = 2                                          # bumped after a recompile
    self.issuer_fees = 20                                   # in bips
    self.minimum_collateral_ratio = 12000                   # in bips
    self.liquidity_multiplier = 1 * 10**17                  # 0.1 ether (in wei) per cent of ETH/USD price
    self.erc20_serenus = 0x3052D1c679eA96500fda71A5Af1Bc2f5fAbC0dA0
    self.oracle = 0x31130468244Ec6746D24482B14E68365440AAB0A

@public
def changeOwner(_address: address):
    assert msg.sender == self.owner
    self.owner = _address

@public
def liquidate():
    assert msg.sender == self.owner
    selfdestruct(self.owner)
    
@public
def setParameters(_issuer_fees: uint256, _minimum_collateral_ratio: uint256,
                  _liquidity_multiplier: uint256, _erc20_serenus: address,
                  _oracle: address):
    assert msg.sender == self.owner

    self.nonce += 1
    self.issuer_fees = _issuer_fees                       # in bips
    self.minimum_collateral_ratio = _minimum_collateral_ratio # in bips
    self.liquidity_multiplier = _liquidity_multiplier     # wei per cent of ETH/USD price
    self.erc20_serenus = _erc20_serenus
    self.oracle = _oracle
    
