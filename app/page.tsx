import { redirect } from "next/navigation";
import { connection } from "next/server";

export default async function Home() {
  await connection();

  redirect("/dashboard");
}