# AI Khata - User Flow

> **Simple user journey diagram**

---

## Complete User Flow

```mermaid
graph TB
    Start([Open App]) --> Login[Login/Register]
    Login --> Onboarding[Setup Store<br/>First time only]
    Onboarding --> Home[Home Screen]
    
    Home --> AddBill[Add Bill]
    Home --> Advice[View AI Advice]
    Home --> Inventory[Check Inventory]
    Home --> History[View History]
    
    AddBill --> Scan[Scan Bill]
    AddBill --> Type[Type Bill]
    
    Scan --> Process[OCR Processing]
    Type --> Process
    Process --> Save[Save + Update Stock]
    Save --> Home
    
    Advice --> Home
    Inventory --> Home
    History --> Home
```

---

## Simple Flow Steps

1. **Login** → Enter credentials
2. **Setup** → Choose store type (first time)
3. **Home** → Main dashboard
4. **Add Bill** → Scan or type
5. **AI Advice** → View guidance
6. **Inventory** → Manage stock
7. **History** → View records

---

*Simple user flow - March 2026*
