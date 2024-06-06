defmodule VachanWeb.CampaignWizard.CampaignWizardLive do
  use VachanWeb, :live_view

  @doc """
  Multi step wizard for creation of a campaign.
  - step 1: select people to send it to |> add people if none exist.
  - step 2: create campaign content |> plain text vs mjml.
  - step 3: select the credentials to use to do it. |> add if none exist.
  - step 4: schedule / send.
  - step 5: view status updates.

  There shall be separate components for every step of the process.
  """

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        module={@current_step.module}
        id={@current_step.live_action}
        next_f={@current_step.next}
        current_user={@current_user}
        current_org={@current_org}
        campaign={@campaign}
        live_action={@live_action}
        content={@content}
        recepients={@recepients}
        sender_profile={@sender_profile}
      >
      </.live_component>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:campaign, nil)
     |> assign(:campaign_id, nil)
     |> assign(:content, nil)
     |> assign(:recepients, nil)
     |> assign(:sender_profile, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({VachanWeb.CampaignWizard.ContentStep, {:content, content}}, socket) do
    {:noreply, assign(socket, :content, content)}
  end

  # @impl true
  # def handle_info({_sender, {_message, _object}}, socket) do
  #   {:noreply, socket}
  # end

  defp wizard_steps do
    [
      %{
        live_action: :new,
        module: VachanWeb.CampaignWizard.NewCampaign,
        next: fn campaign_id -> "/wizard/#{campaign_id}/add-recepients/" end
      },
      %{
        live_action: :add_recepients,
        module: VachanWeb.CampaignWizard.AddRecepients,
        next: fn campaign_id -> "/wizard/#{campaign_id}/add-content/" end
      },
      %{
        live_action: :add_content,
        module: VachanWeb.CampaignWizard.ContentStep,
        next: fn campaign_id -> "/wizard/#{campaign_id}/add-sender-profile/" end
      },
      %{
        live_action: :add_sender_profile,
        module: VachanWeb.CampaignWizard.AddSenderProfile,
        next: fn campaign_id -> "/wizard/#{campaign_id}/review/" end
      },
      %{
        live_action: :create_sender_profile,
        module: VachanWeb.CampaignWizard.AddSenderProfile,
        next: fn campaign_id -> "/wizard/#{campaign_id}/add-sender-profile/" end
      },
      %{
        live_action: :review,
        module: VachanWeb.CampaignWizard.Review,
        next: fn campaign_id -> "/campaigns/#{campaign_id}/show/" end
      }
    ]
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:current_step, get_current_step(:new))
  end

  defp apply_action(socket, live_action, %{"id" => campaign_id} = _params) do
    campaign = get_campaign(socket, campaign_id)

    socket
    |> assign(:current_step, get_current_step(live_action))
    |> assign(:campaign, campaign)
    |> assign(:campaign_id, campaign_id)
    |> assign(:content, campaign.content)
    |> assign(:recepients, campaign.recepients)
    |> assign(:sender_profile, campaign.sender_profile)
  end

  defp get_current_step(live_action) do
    wizard_steps()
    |> Enum.filter(fn x -> x.live_action == live_action end)
    |> hd
  end

  defp get_campaign(socket, campaign_id) do
    Vachan.Massmail.Campaign.get_by_id!(campaign_id, ash_opts(socket))
    |> Ash.load!(:sender_profile, ash_opts(socket))
    |> Ash.load!(:content, ash_opts(socket))
    |> Ash.load!(:recepients, ash_opts(socket))
  end
end
