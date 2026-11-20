import UIKit

class CreatePollViewController: UIViewController {
    
    var onPollCreated: ((String, [String], Bool) -> Void)?
    
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    // Question Section
    private let questionTextField = UITextField()
    
    // Options Section
    private let optionsStackView = UIStackView()
    private var optionTextFields: [UITextField] = []
    private var optionRowViews: [UIView] = []
    private let addOptionButton = UIButton(type: .system)
    
    // Settings Section
    private let multipleAnswersSwitch = UISwitch()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupKeyboardDismiss()
        validateForm()
    }
    
    private func setupNavigationBar() {
        title = "New Poll"
        navigationItem.largeTitleDisplayMode = .never
        
        let cancelButton = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem = cancelButton
        
        let createButton = UIBarButtonItem(
            title: "Create",
            style: .done,
            target: self,
            action: #selector(createTapped)
        )
        createButton.isEnabled = false
        navigationItem.rightBarButtonItem = createButton
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        // ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        
        // Content StackView
        contentView.axis = .vertical
        contentView.spacing = 24
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        setupQuestionSection()
        setupOptionsSection()
        setupSettingsSection()
    }
    
    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Question Section
    private func setupQuestionSection() {
        let sectionStack = UIStackView()
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        
        let headerLabel = UILabel()
        headerLabel.text = "QUESTION"
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = .secondaryLabel
        sectionStack.addArrangedSubview(headerLabel)
        
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.cornerCurve = .continuous
        cardView.clipsToBounds = true
        
        questionTextField.placeholder = "Ask a question..."
        questionTextField.font = .systemFont(ofSize: 16)
        questionTextField.clearButtonMode = .whileEditing
        questionTextField.returnKeyType = .next
        questionTextField.translatesAutoresizingMaskIntoConstraints = false
        questionTextField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        
        cardView.addSubview(questionTextField)
        NSLayoutConstraint.activate([
            questionTextField.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            questionTextField.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            questionTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            questionTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
        ])
        
        sectionStack.addArrangedSubview(cardView)
        contentView.addArrangedSubview(sectionStack)
    }
    
    // MARK: - Options Section
    private func setupOptionsSection() {
        let sectionStack = UIStackView()
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        
        let headerLabel = UILabel()
        headerLabel.text = "OPTIONS"
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = .secondaryLabel
        sectionStack.addArrangedSubview(headerLabel)
        
        optionsStackView.axis = .vertical
        optionsStackView.spacing = 1
        optionsStackView.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        optionsStackView.layer.cornerRadius = 12
        optionsStackView.layer.cornerCurve = .continuous
        optionsStackView.clipsToBounds = true
        sectionStack.addArrangedSubview(optionsStackView)
        
        // Add initial 2 options
        addOptionRow(placeholder: "Option 1")
        addOptionRow(placeholder: "Option 2")
        
        // Add Option Button
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "plus.circle.fill")
        config.title = "Add Option"
        config.imagePadding = 6
        config.baseForegroundColor = .systemBlue
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        addOptionButton.configuration = config
        addOptionButton.contentHorizontalAlignment = .leading
        addOptionButton.addTarget(self, action: #selector(addOptionTapped), for: .touchUpInside)
        sectionStack.addArrangedSubview(addOptionButton)
        
        contentView.addArrangedSubview(sectionStack)
    }
    
    private func addOptionRow(placeholder: String, autoFocus: Bool = false) {
        let index = optionTextFields.count
        
        let rowView = UIView()
        rowView.backgroundColor = .secondarySystemGroupedBackground
        rowView.translatesAutoresizingMaskIntoConstraints = false
        rowView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        
        let bulletIcon = UIImageView(image: UIImage(systemName: "circle"))
        bulletIcon.tintColor = .systemGray4
        bulletIcon.contentMode = .scaleAspectFit
        bulletIcon.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(bulletIcon)
        
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: 16)
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        rowView.addSubview(textField)
        
        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(deleteOptionTapped(_:)), for: .touchUpInside)
        rowView.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            bulletIcon.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 14),
            bulletIcon.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            bulletIcon.widthAnchor.constraint(equalToConstant: 18),
            bulletIcon.heightAnchor.constraint(equalToConstant: 18),
            
            textField.leadingAnchor.constraint(equalTo: bulletIcon.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            textField.topAnchor.constraint(equalTo: rowView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: rowView.bottomAnchor),
            
            deleteButton.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            deleteButton.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        optionsStackView.addArrangedSubview(rowView)
        optionTextFields.append(textField)
        optionRowViews.append(rowView)
        
        updateDeleteButtonsVisibility()
        validateForm()
        
        if autoFocus {
            textField.becomeFirstResponder()
        }
    }
    
    private func updateDeleteButtonsVisibility() {
        let canDelete = optionRowViews.count > 2
        for row in optionRowViews {
            let deleteBtn = row.subviews.compactMap { $0 as? UIButton }.first
            deleteBtn?.isHidden = !canDelete
        }
    }
    
    @objc private func addOptionTapped() {
        guard optionRowViews.count < 10 else {
            let alert = UIAlertController(title: "Option Limit", message: "You can add up to 10 options per poll.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let nextIndex = optionRowViews.count + 1
        addOptionRow(placeholder: "Option \(nextIndex)", autoFocus: true)
    }
    
    @objc private func deleteOptionTapped(_ sender: UIButton) {
        guard let rowView = sender.superview,
              let index = optionRowViews.firstIndex(of: rowView) else { return }
        
        guard optionRowViews.count > 2 else { return }
        
        optionsStackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        optionTextFields.remove(at: index)
        optionRowViews.remove(at: index)
        
        updateDeleteButtonsVisibility()
        validateForm()
    }
    
    // MARK: - Settings Section
    private func setupSettingsSection() {
        let sectionStack = UIStackView()
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        
        let headerLabel = UILabel()
        headerLabel.text = "SETTINGS"
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = .secondaryLabel
        sectionStack.addArrangedSubview(headerLabel)
        
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.cornerCurve = .continuous
        cardView.clipsToBounds = true
        
        let titleLabel = UILabel()
        titleLabel.text = "Allow multiple answers"
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        multipleAnswersSwitch.isOn = true
        multipleAnswersSwitch.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(multipleAnswersSwitch)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: multipleAnswersSwitch.leadingAnchor, constant: -8),
            
            multipleAnswersSwitch.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            multipleAnswersSwitch.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            
            cardView.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        sectionStack.addArrangedSubview(cardView)
        
        let descLabel = UILabel()
        descLabel.text = "Group members can cast votes for more than one option."
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        sectionStack.addArrangedSubview(descLabel)
        
        contentView.addArrangedSubview(sectionStack)
    }
    
    // MARK: - Validation & Actions
    @objc private func textDidChange() {
        validateForm()
    }
    
    private func validateForm() {
        let questionTrimmed = questionTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let validOptions = optionTextFields
            .map { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
            .filter { !$0.isEmpty }
        
        let isValid = !questionTrimmed.isEmpty && validOptions.count >= 2
        navigationItem.rightBarButtonItem?.isEnabled = isValid
    }
    
    @objc private func cancelTapped() {
        view.endEditing(true)
        dismiss(animated: true)
    }
    
    @objc private func createTapped() {
        view.endEditing(true)
        let question = questionTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let validOptions = optionTextFields
            .map { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
            .filter { !$0.isEmpty }
        
        guard !question.isEmpty, validOptions.count >= 2 else { return }
        
        let allowsMultiple = multipleAnswersSwitch.isOn
        dismiss(animated: true) { [weak self] in
            self?.onPollCreated?(question, validOptions, allowsMultiple)
        }
    }
}
