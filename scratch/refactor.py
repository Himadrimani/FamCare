import re

def get_back_button_code():
    return """    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)), for: .normal)
        button.tintColor = .label
        
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
        
        button.insertSubview(blurView, at: 0)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: button.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return button
    }()"""

def update_login_signup():
    path = "/Users/namanmittal/Downloads/ProjectiOS 2/HomeScreen/Auth/LoginSignupViewController.swift"
    with open(path, "r") as f:
        content = f.read()

    # In ForgotPasswordViewController (around line 813)
    # Replace backToLoginButton with backButton
    old_back_button = r"""    private lazy var backToLoginButton: UIButton = \{
        let button = UIButton\(type: \.system\)
        button\.setTitle\("Back to Login", for: \.normal\)
        button\.setImage\(UIImage\(systemName: "chevron\.left"\), for: \.normal\)
        button\.tintColor = \.systemBlue
        button\.titleLabel\?\.font = \.systemFont\(ofSize: 15, weight: \.medium\)
        button\.imageEdgeInsets = UIEdgeInsets\(top: 0, left: -8, bottom: 0, right: 0\)
        button\.translatesAutoresizingMaskIntoConstraints = false
        button\.addTarget\(self, action: #selector\(backTapped\), for: \.touchUpInside\)
        return button
    \}"""
    content = re.sub(old_back_button, get_back_button_code(), content)

    # In setupLayout of ForgotPasswordViewController
    content = content.replace("let backStack = UIStackView(arrangedSubviews: [backToLoginButton, UIView()])", "")
    content = content.replace("contentStack.addArrangedSubview(backStack)", "")
    
    # Add backButton to view in setupLayout
    content = content.replace("view.addSubview(spinner)", "view.addSubview(spinner)\n        view.addSubview(backButton)")
    
    # Add constraints
    content = content.replace(
        "            scrollView.topAnchor.constraint(equalTo: view.topAnchor),",
        "            scrollView.topAnchor.constraint(equalTo: view.topAnchor),\n            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),\n            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),"
    )
    
    with open(path, "w") as f:
        f.write(content)

def update_signup_family():
    path = "/Users/namanmittal/Downloads/ProjectiOS 2/HomeScreen/Auth/SignupFamilyViewController.swift"
    with open(path, "r") as f:
        content = f.read()
        
    # --- SignupFamilyViewController ---
    old_back_button = r"""    private lazy var backToLoginButton: UIButton = \{
        let button = UIButton\(type: \.system\)
        button\.setTitle\("Back to Login", for: \.normal\)
        button\.setImage\(UIImage\(systemName: "chevron\.left"\), for: \.normal\)
        button\.tintColor = \.systemBlue
        button\.titleLabel\?\.font = \.systemFont\(ofSize: 15, weight: \.medium\)
        button\.imageEdgeInsets = UIEdgeInsets\(top: 0, left: -8, bottom: 0, right: 0\)
        button\.translatesAutoresizingMaskIntoConstraints = false
        button\.addTarget\(self, action: #selector\(backTapped\), for: \.touchUpInside\)
        return button
    \}"""
    content = re.sub(old_back_button, get_back_button_code(), content)
    
    content = content.replace("cardView.addSubview(backToLoginButton)", "")
    content = content.replace("""            backToLoginButton.topAnchor.constraint(equalTo: createCard.bottomAnchor, constant: 32),
            backToLoginButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            backToLoginButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -32)""", 
            """            createCard.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -32)""")
    
    # Add backButton to view and constraints for SignupFamilyViewController
    content = re.sub(r'(func setupUI\(\) \{.*?view\.addSubview\(scrollView\))', r'\1\n        view.addSubview(backButton)', content, count=1, flags=re.DOTALL)
    content = re.sub(r'(scrollView\.topAnchor\.constraint\(equalTo: view\.topAnchor\),)', 
                     r'\1\n            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),\n            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),', 
                     content, count=1)
                     
    # --- JoinFamilyViewController ---
    join_class_match = r'(final class JoinFamilyViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate \{.*?private var customSelectedImage: UIImage\?)'
    content = re.sub(join_class_match, r'\1\n\n' + get_back_button_code(), content, flags=re.DOTALL)
    
    # In JoinFamilyViewController's setupUI
    join_setupui_match = r'(// MARK: - Lifecycle\n    override func viewDidLoad\(\) \{.*?\n    private func setupUI\(\) \{.*?view\.addSubview\(scrollView\))'
    content = re.sub(join_setupui_match, r'\1\n        view.addSubview(backButton)', content, flags=re.DOTALL)
    
    # JoinFamilyViewController constraints
    # Since there are multiple scrollView.topAnchor constraints, we replace the one in JoinFamilyViewController
    join_constraints_match = r'(scrollView\.topAnchor\.constraint\(equalTo: view\.safeAreaLayoutGuide\.topAnchor\),)'
    content = re.sub(join_constraints_match, r'\1\n            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),\n            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),', content, count=1)
    
    # Add backTapped to JoinFamilyViewController
    join_backtapped = """\n    @objc private func backTapped() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }"""
    # Insert backTapped before the end of JoinFamilyViewController (before CreateFamilyViewController starts)
    content = re.sub(r'(\n// MARK: - CreateFamilyViewController)', join_backtapped + r'\1', content)
    
    # --- CreateFamilyViewController ---
    create_class_match = r'(final class CreateFamilyViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate \{.*?private var customSelectedImage: UIImage\?)'
    content = re.sub(create_class_match, r'\1\n\n' + get_back_button_code(), content, flags=re.DOTALL)
    
    create_setupui_match = r'(title = "Create Family".*?view\.addSubview\(scrollView\))'
    content = re.sub(create_setupui_match, r'\1\n        view.addSubview(backButton)', content, flags=re.DOTALL)
    
    # CreateFamilyViewController constraints
    # Since this is the second occurrence of view.safeAreaLayoutGuide.topAnchor
    parts = content.split("scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),")
    if len(parts) == 3: # 1 from JoinFamily, 1 from CreateFamily (after substitution above there will be 2 matches in the array split, wait. The join one was already replaced! So there should be only 1 left!)
        # Actually the join one was replaced with `scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),` as well.
        # Let's just find all and replace the last one.
        pass
    
    # Better way: replace the last occurrence
    idx = content.rfind("scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),")
    if idx != -1:
        insert_str = "\n            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),\n            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),"
        content = content[:idx+len("scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),")] + insert_str + content[idx+len("scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),"):]

    # Add backTapped to CreateFamilyViewController at the end of the file
    # We replace the last closing brace
    content = re.sub(r'\}\s*$', join_backtapped + '\n}', content)

    with open(path, "w") as f:
        f.write(content)

update_login_signup()
update_signup_family()
print("Done")
