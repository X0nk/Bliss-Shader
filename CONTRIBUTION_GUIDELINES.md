# Contribution Guidelines

### 1. General Contribution Guidelines

- Before opening a pull request, check for existing issues or discussions related to your changes
- Keep PRs focused, that is avoid mixing multiple unrelated changes/features in a single pull request
- Follow the existing project structure and coding style
- Include meaningful commit messages

---

### 2. Pull Request Rules

- All pull requests should be derived from `unstable-development` brach and submitted back to it
- Pull requests should have a meaningful title and description explaining the changes
- If modifying existing functionality, provide a summary of the before/after behavior

---

### 3. Shader Code Guidelines

- **Coding Style:**
  - Use consistent indentation (tabs/spaces, whichever the project uses) *(GLHF)*
  - Keep shader code well-commented where necessary
  - Keep function and variable names descriptive where possible

- **Performance Best Practices:**
  - Avoid unnecessary operations in the fragment and vertex shaders
  - Use preprocessor directives (`#ifdef`) to conditionally enable features where possible
  - Optimize texture sampling and avoid redundant calculations

---

### 4. Dot Properties Guidelines <sup>*(`block`, `item` and `entity`)*</sup>
- PLS update the tempates from [shaders/template](./shaders/template/) alongside the main files changes
- Each entry in the material `.properties` files has to be sorted, in following ways:
  - Each mod should be placed in separate line for a given entry (1 line per mod)
  - Mod lines should be sorted alphabetically by their ids in ascending order (a -> z)

---

### 5. Testing & Validation

- Changes should be tested before submission to ensure they work correctly
- Ensure new features do not break existing ones

<br><br><br>

## How to add guides:

### Mod support:

- Templates & Coloured Lights: [see this](./shaders/template/readme.md)
- TODO: add more