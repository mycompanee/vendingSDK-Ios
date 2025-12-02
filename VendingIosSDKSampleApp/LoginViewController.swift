//
//  LoginViewController.swift
//  VendingIosSDKSampleApp
//
//  Created on $(DATE).
//

import UIKit
import VendingIosSDK

class LoginViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let authKeyTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Auth Key"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let vendingMachineNumberTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Vending Machine Number"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let apiKeyTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "API Key"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let connectionTimeoutTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Connection Timeout (seconds) - Default: 30"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.text = "30" // Default value
        return textField
    }()
    
    // MARK: - Keyboard Management
    private var keyboardHeight: CGFloat = 0
    
    private let startVendingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Vending", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let abortVendingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Abort", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()
    
    private let statusTextView: UITextView = {
        let textView = UITextView()
        textView.text = ""
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.textColor = .systemBlue
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupKeyboardToolbars()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Vending SDK"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(authKeyTextField)
        contentView.addSubview(vendingMachineNumberTextField)
        contentView.addSubview(apiKeyTextField)
        contentView.addSubview(connectionTimeoutTextField)
        contentView.addSubview(startVendingButton)
        contentView.addSubview(abortVendingButton)
        contentView.addSubview(statusTextView)
        
        startVendingButton.addTarget(self, action: #selector(startVendingButtonTapped), for: .touchUpInside)
        abortVendingButton.addTarget(self, action: #selector(abortVendingButtonTapped), for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupKeyboardToolbars() {
        // Toolbar for number pad
        let numberPadToolbar = UIToolbar()
        numberPadToolbar.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        numberPadToolbar.items = [flexSpace, doneButton]
        vendingMachineNumberTextField.inputAccessoryView = numberPadToolbar
        connectionTimeoutTextField.inputAccessoryView = numberPadToolbar
        
        // Toolbar for auth key and API key text fields (optional, but good UX)
        let authKeyToolbar = UIToolbar()
        authKeyToolbar.sizeToFit()
        let authKeyDoneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        let authKeyFlexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        authKeyToolbar.items = [authKeyFlexSpace, authKeyDoneButton]
        authKeyTextField.inputAccessoryView = authKeyToolbar
        apiKeyTextField.inputAccessoryView = authKeyToolbar
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        self.keyboardHeight = keyboardHeight
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // Scroll to active text field if needed
        if let activeTextField = findActiveTextField() {
            let textFieldFrame = activeTextField.convert(activeTextField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(textFieldFrame, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        let contentInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        keyboardHeight = 0
    }
    
    private func findActiveTextField() -> UITextField? {
        if authKeyTextField.isFirstResponder {
            return authKeyTextField
        } else if vendingMachineNumberTextField.isFirstResponder {
            return vendingMachineNumberTextField
        } else if apiKeyTextField.isFirstResponder {
            return apiKeyTextField
        } else if connectionTimeoutTextField.isFirstResponder {
            return connectionTimeoutTextField
        }
        return nil
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Auth Key TextField
            authKeyTextField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            authKeyTextField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            authKeyTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            authKeyTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            authKeyTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Vending Machine Number TextField
            vendingMachineNumberTextField.topAnchor.constraint(equalTo: authKeyTextField.bottomAnchor, constant: 20),
            vendingMachineNumberTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            vendingMachineNumberTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            vendingMachineNumberTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // API Key TextField
            apiKeyTextField.topAnchor.constraint(equalTo: vendingMachineNumberTextField.bottomAnchor, constant: 20),
            apiKeyTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            apiKeyTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            apiKeyTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Connection Timeout TextField
            connectionTimeoutTextField.topAnchor.constraint(equalTo: apiKeyTextField.bottomAnchor, constant: 15),
            connectionTimeoutTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            connectionTimeoutTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            connectionTimeoutTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Start Vending Button
            startVendingButton.topAnchor.constraint(equalTo: connectionTimeoutTextField.bottomAnchor, constant: 20),
            startVendingButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            startVendingButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            startVendingButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Abort Vending Button
            abortVendingButton.topAnchor.constraint(equalTo: startVendingButton.bottomAnchor, constant: 15),
            abortVendingButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            abortVendingButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            abortVendingButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Status TextView
            statusTextView.topAnchor.constraint(equalTo: abortVendingButton.bottomAnchor, constant: 20),
            statusTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            statusTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            statusTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            statusTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func startVendingButtonTapped() {
        guard let authKey = authKeyTextField.text, !authKey.isEmpty else {
            showAlert(title: "Error", message: "Please enter an auth key first")
            return
        }
        
        guard let apiKey = apiKeyTextField.text, !apiKey.isEmpty else {
            showAlert(title: "Error", message: "Please enter an API key first")
            return
        }
        
        guard let machineNumberText = vendingMachineNumberTextField.text,
              let machineNumber = Int32(machineNumberText) else {
            showAlert(title: "Error", message: "Please enter a valid vending machine number")
            return
        }
        
        // Disable UI
        startVendingButton.isEnabled = false
        authKeyTextField.isEnabled = false
        vendingMachineNumberTextField.isEnabled = false
        apiKeyTextField.isEnabled = false
        connectionTimeoutTextField.isEnabled = false
        abortVendingButton.isEnabled = true
        abortVendingButton.isHidden = false
        statusTextView.text = ""
        
        // Parse connection timeout (default to 30 seconds)
        let connectionTimeout: TimeInterval = {
            if let timeoutText = connectionTimeoutTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !timeoutText.isEmpty,
               let timeout = Double(timeoutText),
               timeout > 0 {
                return timeout
            }
            return 30.0 // Default value
        }()
        
        // Start vending workflow
        VendingSDK.shared.startVending(
            authKey: authKey,
            apiKey: apiKey,
            vendingMachineNumber: machineNumber,
            connectionTimeout: connectionTimeout,
            statusCallback: { [weak self] status in
                DispatchQueue.main.async {
                    self?.statusTextView.text = (self?.statusTextView.text ?? "") + status + "\n"
                    // Scroll to bottom
                    let bottom = NSRange(location: (self?.statusTextView.text.count ?? 0) - 1, length: 1)
                    self?.statusTextView.scrollRangeToVisible(bottom)
                    
                    // Re-enable UI if connection failed, timed out, or any error occurred
                    let lowercasedStatus = status.lowercased()
                    if lowercasedStatus.contains("timeout") ||
                       lowercasedStatus.contains("connection timeout") ||
                       lowercasedStatus.contains("connection failed") ||
                       lowercasedStatus.contains("could not connect") ||
                       lowercasedStatus.contains("could not find device") ||
                       lowercasedStatus.contains("connection lost") ||
                       lowercasedStatus.contains("failed to") ||
                       lowercasedStatus.contains("failed:") ||
                       lowercasedStatus.contains("not found") ||
                       lowercasedStatus.contains("bluetooth is not") ||
                       lowercasedStatus.contains("authentication failed") ||
                       (lowercasedStatus == "disconnected" && self?.startVendingButton.isEnabled == false) {
                        self?.startVendingButton.isEnabled = true
                        self?.authKeyTextField.isEnabled = true
                        self?.vendingMachineNumberTextField.isEnabled = true
                        self?.apiKeyTextField.isEnabled = true
                        self?.connectionTimeoutTextField.isEnabled = true
                        self?.abortVendingButton.isEnabled = false
                    }
                }
            },
            transactionCallback: { [weak self] result in
                DispatchQueue.main.async {
                    self?.startVendingButton.isEnabled = true
                    self?.authKeyTextField.isEnabled = true
                    self?.vendingMachineNumberTextField.isEnabled = true
                    self?.apiKeyTextField.isEnabled = true
                    self?.connectionTimeoutTextField.isEnabled = true
                    self?.abortVendingButton.isEnabled = false
                    
                    var message = "Transaction Completed!\n\n"
                    message += "Selection: \(result.selection)\n"
                    message += "Amount: \(result.amount)\n"
                    message += "Fingerprint: \(result.fingerprint)\n"
                    
                    if let article = result.article {
                        message += "Article: \(article.name) (PLU: \(article.plu))\n"
                    }
                    
                    if let response = result.transactionResponse {
                        message += "\nBackend Response:\n"
                        message += "Balance Old: \(response.balanceOld)\n"
                        message += "Balance New: \(response.balanceNew)\n"
                        message += "Total Gross: \(response.totalGross)\n"
                        if let invoiceNumber = response.invoiceNumber {
                            message += "Invoice Number: \(invoiceNumber)\n"
                        }
                    }
                    
                    // Show transaction details from convenience properties
                    if let terminalName = result.terminalName {
                        message += "\nTerminal Name: \(terminalName)\n"
                    }
                    if let storeName = result.storeName {
                        message += "Store Name: \(storeName)\n"
                    }
                    if let transactionUUID = result.transactionUUID {
                        message += "Transaction UUID: \(transactionUUID)\n"
                    }
                    
                    self?.showAlert(title: "Vending Transaction", message: message)
                }
            }
        )
    }
    
    @objc private func abortVendingButtonTapped() {
        // Abort the current vending session
        VendingSDK.shared.abortVending()
        
        // Update UI
        startVendingButton.isEnabled = true
        authKeyTextField.isEnabled = true
        vendingMachineNumberTextField.isEnabled = true
        apiKeyTextField.isEnabled = true
        connectionTimeoutTextField.isEnabled = true
        abortVendingButton.isEnabled = false
        
        // Update status
        statusTextView.text = (statusTextView.text ?? "") + "Session aborted by user\n"
        let bottom = NSRange(location: (statusTextView.text.count) - 1, length: 1)
        statusTextView.scrollRangeToVisible(bottom)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

