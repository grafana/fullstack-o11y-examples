import React, { createContext, useContext, useState } from "react";

// Mock authentication: the "logged-in" customer is one of the seeded customers,
// persisted in localStorage. No password — this is a demo of the app flow.
const AuthContext = createContext(null);
const STORAGE_KEY = "bookstore.customer";

function loadCustomer() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || null;
  } catch {
    return null;
  }
}

export function AuthProvider({ children }) {
  const [customer, setCustomer] = useState(loadCustomer);

  const login = (c) => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(c));
    setCustomer(c);
  };
  const logout = () => {
    localStorage.removeItem(STORAGE_KEY);
    setCustomer(null);
  };

  return (
    <AuthContext.Provider value={{ customer, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
