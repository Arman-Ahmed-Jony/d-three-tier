import cors from "cors";
import dotenv from "dotenv";
import express from "express";
import mongoose from "mongoose";
import todosRouter from "./routes/todos.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5001;
const MONGODB_URI =
  process.env.MONGODB_URI || "mongodb://127.0.0.1:27017/todo-app";

app.use(cors());
app.use(express.json());

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/api/todos", todosRouter);

async function start() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log("Connected to MongoDB");

    app.listen(PORT, () => {
      console.log(`Service running on http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error("Failed to start service:", error.message);
    process.exit(1);
  }
}

start();
