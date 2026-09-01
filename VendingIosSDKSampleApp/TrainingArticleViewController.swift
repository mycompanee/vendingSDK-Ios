//
//  TrainingArticleViewController.swift
//  VendingIosSDKSampleApp
//
//  Created on $(DATE).
//

import UIKit
import VendingIosSDK

/// Article assignment UI for training mode (port of legacy VendingArticleTraining page)
class TrainingArticleViewController: UIViewController {
    
    // MARK: - Properties
    
    private let authKey: String
    private let apiKey: String
    private let machineNumber: Int32
    private let product: VendingTrainingProduct
    
    private var vendingBaseData: VendingBaseDataResponse?
    private var allArticles: [VendingArticle] = []
    private var filteredArticles: [VendingArticle] = []
    private var assignedArticle: VendingArticle?
    
    private var isAssigning = false
    
    // MARK: - UI Components
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .systemBlue
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let selectionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let assignedArticleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .systemGreen
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let filterTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "PLU / Artikel Filter..."
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let articleTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let createArticleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Artikel erstellen", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Abbrechen", for: .normal)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Init
    
    init(authKey: String, apiKey: String, machineNumber: Int32, product: VendingTrainingProduct, vendingBaseData: VendingBaseDataResponse?) {
        self.authKey = authKey
        self.apiKey = apiKey
        self.machineNumber = machineNumber
        self.product = product
        self.vendingBaseData = vendingBaseData
        super.init(nibName: nil, bundle: nil)
        
        self.allArticles = vendingBaseData?.vendingArticles ?? []
        self.filteredArticles = allArticles
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Artikel zuordnen"
        
        articleTableView.dataSource = self
        articleTableView.delegate = self
        articleTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ArticleCell")
        
        filterTextField.addTarget(self, action: #selector(filterTextChanged), for: .editingChanged)
        createArticleButton.addTarget(self, action: #selector(createArticleTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        view.addSubview(infoLabel)
        view.addSubview(selectionLabel)
        view.addSubview(assignedArticleLabel)
        view.addSubview(filterTextField)
        view.addSubview(articleTableView)
        view.addSubview(createArticleButton)
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            selectionLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 10),
            selectionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            selectionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            selectionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            assignedArticleLabel.topAnchor.constraint(equalTo: selectionLabel.bottomAnchor, constant: 10),
            assignedArticleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            assignedArticleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            filterTextField.topAnchor.constraint(equalTo: assignedArticleLabel.bottomAnchor, constant: 12),
            filterTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            filterTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            filterTextField.heightAnchor.constraint(equalToConstant: 44),
            
            articleTableView.topAnchor.constraint(equalTo: filterTextField.bottomAnchor, constant: 12),
            articleTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            articleTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            createArticleButton.topAnchor.constraint(equalTo: articleTableView.bottomAnchor, constant: 12),
            createArticleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            createArticleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            createArticleButton.heightAnchor.constraint(equalToConstant: 44),
            
            cancelButton.topAnchor.constraint(equalTo: createArticleButton.bottomAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }
    
    private func setupData() {
        let price = Double(product.amount) / 100.0
        selectionLabel.text = " Wahl: \(product.selection)   Preis: \(String(format: "%.2f", price)) €\((product.isLoading ? "   (Loading)" : "")) "
        
        refreshAssignedArticle()
        
        if let machines = vendingBaseData?.vendingMachines,
           let machine = machines.first(where: { $0.machineNumber == machineNumber }) {
            infoLabel.text = "\(machine.machineName ?? "-") / \(machine.building ?? "-") (\(machine.machineNumber))"
        }
    }
    
    private func refreshAssignedArticle() {
        if let machines = vendingBaseData?.vendingMachines,
           let machine = machines.first(where: { $0.machineNumber == machineNumber }),
           let mappings = vendingBaseData?.vendingMachineArticleMappings,
           let mapping = mappings.first(where: { $0.vendingMachineId == machine.id && $0.selection == product.selection }),
           let article = vendingBaseData?.vendingArticles?.first(where: { $0.id == mapping.vendingArticleId }) {
            assignedArticle = article
            assignedArticleLabel.text = "Aktuell zugeordneter Artikel: \(article.plu) - \(article.name)"
        } else {
            assignedArticle = nil
            assignedArticleLabel.text = "Aktuell zugeordneter Artikel: -"
        }
    }
    
    // MARK: - Actions
    
    @objc private func filterTextChanged() {
        let text = filterTextField.text ?? ""
        if text.isEmpty {
            filteredArticles = allArticles
        } else {
            filteredArticles = allArticles.filter { $0.name.contains(text) || $0.plu.contains(text) }
        }
        articleTableView.reloadData()
    }
    
    @objc private func createArticleTapped() {
        let alert = UIAlertController(
            title: "Neuen Artikel anlegen",
            message: "Bitte Artikel wie folgt eingeben: [PLU]:[Name]",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "123:My New Article"
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self,
                  let input = alert.textFields?.first?.text,
                  input.contains(":") else {
                self?.showAlert(title: "Da ist was Schief gelaufen!", message: "Bitte Format [PLU]:[Name] verwenden")
                return
            }
            
            let parts = input.components(separatedBy: ":")
            guard parts.count == 2 else {
                self.showAlert(title: "Da ist was Schief gelaufen!", message: "Bitte Format [PLU]:[Name] verwenden")
                return
            }
            
            let plu = parts[0].trimmingCharacters(in: .whitespaces)
            let name = parts[1].trimmingCharacters(in: .whitespaces)
            
            guard !plu.isEmpty && !name.isEmpty else {
                self.showAlert(title: "Da ist was Schief gelaufen!", message: "PLU und Name dürfen nicht leer sein")
                return
            }
            
            self.setUIEnabled(false)
            VendingSDK.shared.createVendingArticle(authKey: self.authKey, apiKey: self.apiKey, plu: plu, name: name) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.setUIEnabled(true)
                    switch result {
                    case .success:
                        // Reload base data and filter to the new article (matches legacy behavior)
                        VendingSDK.shared.reloadVendingBaseData(authKey: self.authKey, apiKey: self.apiKey) { [weak self] baseDataResult in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                if case .success(let baseData) = baseDataResult {
                                    self.vendingBaseData = baseData
                                    self.allArticles = baseData.vendingArticles ?? []
                                    self.filterTextField.text = plu
                                    self.filterTextChanged()
                                    self.refreshAssignedArticle()
                                }
                                self.showAlert(title: "Artikel erstellt", message: "\(plu) - \(name)")
                            }
                        }
                    case .failure(let error):
                        self.showAlert(title: "Existiert bereits / Fehler", message: error.localizedDescription)
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Abbruch", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func assignArticle(_ article: VendingArticle) {
        guard !isAssigning else { return }
        isAssigning = true
        setUIEnabled(false)
        
        VendingSDK.shared.assignVendingArticle(
            authKey: authKey,
            apiKey: apiKey,
            machineNumber: machineNumber,
            selection: product.selection,
            newArticle: article
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAssigning = false
                self.setUIEnabled(true)
                
                switch result {
                case .success(let baseData):
                    self.vendingBaseData = baseData
                    self.allArticles = baseData.vendingArticles ?? []
                    self.refreshAssignedArticle()
                    self.showAlert(title: "Artikelzuordnung gespeichert", message: "\(article.plu) - \(article.name) → Wahl \(self.product.selection)") { self.dismiss(animated: true) }
                case .failure(let error):
                    self.showAlert(title: "Da ist was Schief gelaufen!", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func setUIEnabled(_ enabled: Bool) {
        createArticleButton.isEnabled = enabled
        cancelButton.isEnabled = enabled
        filterTextField.isEnabled = enabled
        articleTableView.allowsSelection = enabled
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Habe verstanden!", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension TrainingArticleViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredArticles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ArticleCell", for: indexPath)
        let article = filteredArticles[indexPath.row]
        cell.textLabel?.text = "\(article.plu) - \(article.name)"
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let article = filteredArticles[indexPath.row]
        
        let question = assignedArticle != nil ? "Artikelzuordnung überschreiben?" : "Artikelzuordnung speichern?"
        let alert = UIAlertController(title: question, message: "\(article.plu) - \(article.name)", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Ja", style: .default) { [weak self] _ in
            self?.assignArticle(article)
        })
        alert.addAction(UIAlertAction(title: "Nein", style: .cancel))
        present(alert, animated: true)
    }
}