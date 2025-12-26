import { Controller } from "@hotwired/stimulus"
import { BrowserProvider, getAddress } from "ethers"

export default class extends Controller {
  static targets = ["address", "connectButton", "connectedInfo", "submitButton", "addressDisplay"]

  connect() {
    // Check if wallet is already connected on page load
    this.checkExistingConnection()
  }

  async checkExistingConnection() {
    if (!window.ethereum) return

    try {
      const provider = new BrowserProvider(window.ethereum)
      const accounts = await provider.send("eth_accounts", [])

      if (accounts && accounts.length > 0) {
        const account = getAddress(accounts[0])
        this.setConnectedState(account)
      }
    } catch (error) {
      console.error("Failed to check connection:", error)
    }
  }

  async connectWallet() {
    if (!window.ethereum) {
      alert("No Ethereum wallet found. Please install MetaMask.")
      return
    }

    try {
      const provider = new BrowserProvider(window.ethereum)
      const accounts = await provider.send("eth_requestAccounts", [])
      const rawAccount = accounts?.[0]

      if (!rawAccount) {
        alert("No account selected.")
        return
      }

      // Normalize to EIP-55 checksummed format
      const account = getAddress(rawAccount)
      this.setConnectedState(account)

    } catch (error) {
      console.error("Failed to connect wallet:", error)
      if (error.code === 4001) {
        // User rejected the request
        alert("Connection request was rejected.")
      } else {
        alert("Failed to connect wallet. Please try again.")
      }
    }
  }

  disconnectWallet() {
    this.setDisconnectedState()
  }

  setConnectedState(address) {
    // Store address
    this.addressTarget.value = address

    // Show connected info, hide connect button
    if (this.hasConnectButtonTarget) {
      this.connectButtonTarget.classList.add("hidden")
    }
    if (this.hasConnectedInfoTarget) {
      this.connectedInfoTarget.classList.remove("hidden")
    }

    // Update address display
    if (this.hasAddressDisplayTarget) {
      this.addressDisplayTarget.textContent = `${address.slice(0, 6)}...${address.slice(-4)}`
    }

    // Enable submit button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
  }

  setDisconnectedState() {
    // Clear address
    this.addressTarget.value = ""

    // Hide connected info, show connect button
    if (this.hasConnectedInfoTarget) {
      this.connectedInfoTarget.classList.add("hidden")
    }
    if (this.hasConnectButtonTarget) {
      this.connectButtonTarget.classList.remove("hidden")
    }

    // Disable submit button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }
}