import { Controller } from "@hotwired/stimulus"
import { BrowserProvider, formatEther } from "ethers"

export default class extends Controller {
  static targets = ["dropdown", "dropdownMenu", "sidebar", "backdrop", "balance", "balanceMobile", "copyIcon", "checkIcon", "copyIconMobile", "checkIconMobile"]

  connect() {
    // Close dropdown when clicking outside
    this.boundCloseDropdown = this.closeDropdown.bind(this)
    document.addEventListener("click", this.boundCloseDropdown)

    // Fetch balance if user is logged in
    this.fetchBalance()
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseDropdown)
  }

  toggleDropdown(event) {
    event.stopPropagation()
    if (this.hasDropdownMenuTarget) {
      this.dropdownMenuTarget.classList.toggle("hidden")

      // Fetch balance when opening dropdown
      if (!this.dropdownMenuTarget.classList.contains("hidden")) {
        this.fetchBalance()
      }
    }
  }

  toggleMobile() {
    if (this.hasSidebarTarget && this.hasBackdropTarget) {
      const isOpen = !this.sidebarTarget.classList.contains("-translate-x-full")

      if (isOpen) {
        this.closeSidebar()
      } else {
        this.openSidebar()
      }
    }
  }

  openSidebar() {
    // Show backdrop
    this.backdropTarget.classList.remove("hidden")

    // Slide in sidebar
    setTimeout(() => {
      this.sidebarTarget.classList.remove("-translate-x-full")
    }, 10)

    // Fetch balance when opening sidebar
    this.fetchBalance()
  }

  closeSidebar() {
    // Slide out sidebar
    this.sidebarTarget.classList.add("-translate-x-full")

    // Hide backdrop after animation
    setTimeout(() => {
      this.backdropTarget.classList.add("hidden")
    }, 300)
  }

  closeDropdown(event) {
    if (this.hasDropdownTarget && this.hasDropdownMenuTarget) {
      if (!this.dropdownTarget.contains(event.target)) {
        this.dropdownMenuTarget.classList.add("hidden")
      }
    }
  }

  async fetchBalance() {
    if (!this.hasBalanceTarget && !this.hasBalanceMobileTarget) return

    try {
      if (!window.ethereum) {
        this.updateBalance("No wallet")
        return
      }

      const provider = new BrowserProvider(window.ethereum)

      // Get current account
      const accounts = await provider.send("eth_accounts", [])
      if (!accounts || accounts.length === 0) {
        this.updateBalance("Not connected")
        return
      }

      const address = accounts[0]

      // Get balance
      const balanceWei = await provider.getBalance(address)
      const balanceEth = formatEther(balanceWei)

      // Format balance (show 4 decimal places)
      const formatted = parseFloat(balanceEth).toFixed(4)
      this.updateBalance(`${formatted} ETH`)

    } catch (error) {
      console.error("Failed to fetch balance:", error)
      this.updateBalance("Error loading")
    }
  }

  updateBalance(text) {
    if (this.hasBalanceTarget) {
      this.balanceTarget.innerHTML = text
    }
    if (this.hasBalanceMobileTarget) {
      this.balanceMobileTarget.innerHTML = text
    }
  }

  async copyAddress(event) {
    const button = event.currentTarget
    const address = button.dataset.address

    try {
      await navigator.clipboard.writeText(address)

      // Show check icon for desktop
      if (this.hasCopyIconTarget && this.hasCheckIconTarget) {
        this.copyIconTarget.classList.add("hidden")
        this.checkIconTarget.classList.remove("hidden")

        setTimeout(() => {
          this.copyIconTarget.classList.remove("hidden")
          this.checkIconTarget.classList.add("hidden")
        }, 2000)
      }

      // Show check icon for mobile
      if (this.hasCopyIconMobileTarget && this.hasCheckIconMobileTarget) {
        this.copyIconMobileTarget.classList.add("hidden")
        this.checkIconMobileTarget.classList.remove("hidden")

        setTimeout(() => {
          this.copyIconMobileTarget.classList.remove("hidden")
          this.checkIconMobileTarget.classList.add("hidden")
        }, 2000)
      }

    } catch (error) {
      console.error("Failed to copy address:", error)
    }
  }
}
