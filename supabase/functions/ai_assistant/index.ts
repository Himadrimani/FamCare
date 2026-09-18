import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { GoogleGenerativeAI, SchemaType } from "npm:@google/generative-ai";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SYSTEM_PROMPT = `You are the FamCare AI Assistant, a helpful and empathetic family health companion.

IMPORTANT RULES:
1. The user's real health data is provided in the first message of each conversation. Use it to answer questions accurately — NEVER invent or guess health numbers.
2. When summarizing health data, be conversational and supportive. Don't dump raw numbers — explain what they mean and offer encouragement or gentle nudges.
3. If the user asks to create a challenge, use the 'create_challenge' tool. If they don't specify all details, make reasonable assumptions (e.g., 7 days, 10000 steps, include "me"). IMPORTANT: If the user provides a description for the challenge, you MUST pass it in the 'description' field exactly as they said it. If they don't provide a description, set the description to be the same as the challengeName.
4. If the user asks to create a message group, use the 'create_message_group' tool.
5. Keep responses concise (2-4 sentences for simple questions, more for detailed analysis).
6. Always frame health data as general wellness information, never as medical advice.
7. Be warm, use emojis sparingly (1-2 per message max), and celebrate progress.`;

const tools = [{
  functionDeclarations: [
    {
      name: "create_challenge",
      description: "Creates a new health/wellness challenge in the app. Use when the user wants to start a challenge.",
      parameters: {
        type: SchemaType.OBJECT,
        properties: {
          challengeName: { type: SchemaType.STRING, description: "A catchy name for the challenge." },
          description: { type: SchemaType.STRING, description: "A description for the challenge. If the user provides one, use their exact words. Otherwise, set it to be the same as challengeName." },
          metric: { type: SchemaType.STRING, description: "The metric to track: steps, caloriesBurned, distance, or custom." },
          goalValue: { type: SchemaType.NUMBER, description: "The target goal value per person (e.g. 10000 for steps)." },
          durationDays: { type: SchemaType.INTEGER, description: "Duration in days (e.g. 7)." },
          participants: { 
            type: SchemaType.ARRAY, 
            items: { type: SchemaType.STRING },
            description: "List of family member names or 'me'."
          }
        },
        required: ["challengeName", "description", "metric", "goalValue", "durationDays", "participants"]
      }
    },
    {
      name: "create_message_group",
      description: "Creates a new message group for family communication.",
      parameters: {
        type: SchemaType.OBJECT,
        properties: {
          groupName: { type: SchemaType.STRING, description: "Name of the group." },
          participants: { 
            type: SchemaType.ARRAY, 
            items: { type: SchemaType.STRING },
            description: "List of family member names to include."
          }
        },
        required: ["groupName", "participants"]
      }
    }
  ]
}];

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { messages } = await req.json();

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      throw new Error("Invalid request body. 'messages' array is required.");
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      throw new Error("Missing GEMINI_API_KEY. Please set it in Edge Function Secrets.");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ 
      model: "gemini-3.6-flash",
      tools: tools,
      systemInstruction: SYSTEM_PROMPT
    });

    // Convert iOS messages to Gemini history format
    // Filter out any messages with null/empty content
    const validMessages = messages.filter(msg => msg.content && msg.content.trim().length > 0);
    
    if (validMessages.length === 0) {
      throw new Error("No valid messages to process.");
    }

    // Build history from all messages except the last one
    const history = validMessages.slice(0, -1).map(msg => ({
      role: msg.role === "assistant" ? "model" : "user",
      parts: [{ text: msg.content }]
    }));
    
    const latestMessage = validMessages[validMessages.length - 1].content;

    const chat = model.startChat({ history });
    const result = await chat.sendMessage(latestMessage);
    const response = result.response;
    
    // Check for function calls
    const functionCalls = response.functionCalls();
    
    let returnMessage;
    
    if (functionCalls && functionCalls.length > 0) {
      const call = functionCalls[0];
      
      // Also get any text the model generated alongside the function call
      let textContent = null;
      try {
        textContent = response.text();
      } catch (e) {
        // No text content, that's fine
      }
      
      returnMessage = {
        role: "assistant",
        content: textContent,
        tool_calls: [{
          id: "call_" + Math.random().toString(36).substring(7),
          type: "function",
          function: {
            name: call.name,
            arguments: JSON.stringify(call.args)
          }
        }]
      };
    } else {
      returnMessage = {
        role: "assistant",
        content: response.text()
      };
    }

    return new Response(
      JSON.stringify({ message: returnMessage }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "An unexpected error occurred." }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
