defmodule VachanWeb.CampaignBuilder.ContentComponent do
  use VachanWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="">
      <%= if @mode == :edit do %>
        <div>
          <.simple_form
            id="content-form"
            for={@form}
            phx-change="validate"
            phx-submit="preview"
            phx-target={@myself}
            class="p-1"
          >
            <.input
              field={@form[:subject]}
              type="text"
              label="Subject"
              placeholder="How is {{company}}'s marketing campaign holding up?"
            >
            </.input>

            <.input
              field={@form[:text_body]}
              type="textarea"
              rows="10"
              label="Email Body"
              placeholder="The body of the email"
            >
            </.input>

            <.input field={@form[:campaign_id]} type="hidden" value={@campaign.id}></.input>

            <:actions>
              <.button phx-disable-with="Saving ... ">Preview and Send</.button>
            </:actions>
          </.simple_form>
        </div>

        <div>
          <%= for variable <- @column_names do %>
            <%= variable %>
          <% end %>
        </div>
      <% else %>
        <!-- Preview Content -->
        <div class="preview-content">
          <.list>
            <:item title="Subject"><%= @content.subject %></:item>
            <:item title="Variables">
              <span>
                <%= Enum.join(@column_names, ", ") %>
              </span>
            </:item>
            <:item title="Body">
              <%= for line <- String.split(@content.text_body, "\n") do %>
                <p class="break-normal"><%= line %></p>
              <% end %>
            </:item>
          </.list>
        </div>

        <!-- Buttons for Back to Editing and Send -->
        <div class="action-buttons">
          <.button phx-click="edit-mode" phx-target={@myself}>Back to Editing</.button>
          <.button phx-click="send-content" phx-target={@myself}>Send</.button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    mode =
      case assigns.content do
        nil -> :edit
        _ -> :show
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:mode, mode)
     |> assign(:column_names, extract_column_names(assigns))
     |> assign(form: create_form(assigns))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    column_names =
      extract_strings(params["text_body"]) ++ extract_strings(params["subject"])

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:column_names, column_names)}
  end

  @impl true
  def handle_event("edit-mode", _params, socket) do
    {:noreply, socket |> assign(:mode, :edit)}
  end

  @impl true
  def handle_event("preview", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    case AshPhoenix.Form.submit(form) do
      {:ok, content} ->
        notify_parent({:content, content})

        {:noreply,
         socket
         |> assign(:content, content)
         |> assign(:mode, :show)}

      {:error, form} ->
        IO.inspect(form)
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("send-content", _params, socket) do
    # Logic for sending the content
    {:noreply, socket |> put_flash(:info, "Content Sent")}
  end

  defp create_form(assigns) do
    case assigns.content do
      nil ->
        Vachan.Massmail.Content
        |> AshPhoenix.Form.for_create(
          :create,
          ash_opts(assigns, domain: Vachan.Massmail)
        )
        |> to_form()

      content ->
        content
        |> AshPhoenix.Form.for_update(
          :update,
          ash_opts(assigns, domain: Vachan.Massmail)
        )
        |> to_form()
    end
  end

  defp extract_column_names(assigns) do
    case assigns.content do
      nil ->
        []

      content ->
        content
        |> Ash.load!(:columns, ash_opts(assigns, domain: Vachan.Massmail))
        |> then(fn c -> c.columns end)
    end
  end

  defp extract_strings(input_string) do
    ~r/{{(.*?)}}/s
    |> Regex.scan(input_string)
    |> Enum.map(&List.last(&1))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
