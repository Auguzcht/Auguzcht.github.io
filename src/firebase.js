// Import Firebase functions
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAnalytics } from "firebase/analytics";
import { collection, addDoc, getDocs } from "@firebase/firestore";

// Your web app's Firebase configuration (Replace this with your credentials)
const firebaseConfig = {
  apiKey: "AIzaSyBqd2bL6qREBtZqnmBnBUYDptT618QjVyM",
  authDomain: "nodado-portfolio.firebaseapp.com",
  projectId: "nodado-portfolio",
  storageBucket: "nodado-portfolio.appspot.com",
  messagingSenderId: "896748957589",
  appId: "1:896748957589:web:b6c542b887f438f01b909c",
  measurementId: "G-DLG7VQ1PJR",
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const analytics = getAnalytics(app); 

// Export Firebase services
export { db, collection, addDoc, getDocs, analytics };