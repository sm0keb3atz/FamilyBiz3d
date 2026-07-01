# Family Business - Game Design Document Index

Welcome to the Game Design Document (GDD) hub for **Family Business**. This document serves as the central directory and high-level architectural roadmap for the game design. It is structured modularly so that developer agents and collaborators can easily navigate the design specifications.

---

## 📖 Game Overview
**Family Business** is a low-poly life simulator and empire-management game. Players begin as low-level street dealers buying and selling contraband to build territory, purchase properties, clean dirty money, and ultimately rise to the position of a Kingpin running a city-wide wholesale network.

---

## 📂 Document Directory

Click the links below to access the specific design specifications:


### 1. [Core Concept & Design Pillars](file:///c:/Users/smo0o/OneDrive/Desktop/shh/Project%20material/Family%20Business/Projects/FamilyBusiness/Docs/GameDoc/GDD_Core_Concept.md)
*High-level summary of the game, target audience, art style (low-poly), and core gameplay loop.*

### 2. [Player Stats System](file:///c:/Users/smo0o/OneDrive/Desktop/shh/Project%20material/Family%20Business/Projects/FamilyBusiness/Docs/GameDoc/GDD_Player_Stats.md)
*Detailed breakdown of Player attributes: Health, Stamina, Aura (and the Relationship System), EXP, and Level progression.*

### 3. [Territory Stats & Heat](file:///c:/Users/smo0o/OneDrive/Desktop/shh/Project%20material/Family%20Business/Projects/FamilyBusiness/Docs/GameDoc/GDD_Territory_Stats.md)
*Details of local per-territory metrics: Police Heat levels, Reputation/Respect, and territory-based pricing dynamics.*

### 4. [Money & Economy System](file:///c:/Users/smo0o/OneDrive/Desktop/shh/Project%20material/Family%20Business/Projects/FamilyBusiness/Docs/GameDoc/GDD_Money_System.md)
*Explores the mechanics of Dirty Money vs. Clean Money, stash houses, bank accounts, and money laundering.*

---

## 🛠️ Project Foundation Note
This project is built using **Unreal Engine 5.7** and leverages the **Game Animation Sample Project (GASP)** as its locomotion foundation. Base locomotion (climbing, sliding, sprinting, vaulting) and interactive Smart Objects are handled using the GASP Mover component, Motion Matching, and State Tree settings.
