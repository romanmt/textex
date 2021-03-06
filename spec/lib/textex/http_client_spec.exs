defmodule Textex.HttpClientSpec do
  use ESpec
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias Textex.HttpClient
  alias Textex.SmsMessage

  let :real_valid_phone_number,   do: "5164293004" #"8065843004"
  let :real_invalid_phone_number, do: "516429300" #"(806) 584-3004"
  let :fake_valid_phone_number,   do: "5555555555"
  let :fake_invalid_phone_number, do: "(555) 555-5555"
  let :test_group,                do: "Test"
  let :invalid_group,             do: "Nongroup"

  let :sms_message_success_result do
    HttpClient.sms_message_success_result()
  end

  let :incorrectly_formatted_phone_number_error_result do
    HttpClient.incorrectly_formatted_phone_number_error_result()
  end

  let :invalid_group_error_result do
    HttpClient.invalid_group_error_result()
  end

  let :invalid_message_or_subject_error_result do
    HttpClient.invalid_message_or_subject_error_result()
  end

  let :insufficient_credits_error_result do
    HttpClient.insufficient_credits_error_result()
  end

  let :invalid_stamp_error_result do
    HttpClient.invalid_stamp_error_result("yesterday")
  end

  describe "get_retrieve_all_groups!" do
    let :override_base_uri, do: nil

    context "when the mode is :production" do

      subject do
        use_cassette(cassette()) do
          result()
        end
      end

      let :successful_result, do:
      {:ok, [
          %{"ContactCount" => 0, "ID" => 482969, "Name" => "Keyword", "Note" => ""},
          %{"ContactCount" => 1, "ID" => 482968, "Name" => "Test", "Note" => ""},
          %{"ContactCount" => 0, "ID" => 482970, "Name" => "Widget", "Note" => ""}
        ]
      }

      context "when using the correct base URL" do

        let :override_base_uri, do: Application.get_env(:textex, :base_sends_uri)

        let :result, do: HttpClient.get_retrieve_all_groups(override_base_uri(), :production)

        let :cassette, do: "group_retrieve_all_success"

        it do: is_expected() |> to(eq(successful_result()))

      end

    end

  end

  describe "post_sms_message!" do
    let :override_base_uri, do: nil

    context "when the mode is :test" do
      subject do: HttpClient.post_sms_message!(sms_message(), override_base_uri(), :test)

      context "with a valid sms_message" do
        let :sms_message do
          %SmsMessage{
            phone_number: real_valid_phone_number(),
            message:      "This is a test from ACOP server HttpClientSpec",
          }
        end

        it do: is_expected() |> to(eq(sms_message_success_result()))
      end

      context "with an invalid sms_message" do
        context "with an invalid phone number" do
          let :sms_message do
            %SmsMessage{
              phone_number: real_invalid_phone_number(),
              message:      "This is a test from ACOP server HttpClientSpec",
            }
          end

          it do: is_expected() |> to(eq(sms_message_success_result()))
        end

        context "when the message is missing or nil" do
          let :sms_message do
            %SmsMessage{
              phone_number: real_valid_phone_number(),
            }
          end

          it do: is_expected() |> to(eq(invalid_message_or_subject_error_result()))
        end
      end
    end

    context "when the mode is :production" do
      subject do
        use_cassette(cassette()) do
          result()
        end
      end

      let :result, do: HttpClient.post_sms_message!(sms_message(), override_base_uri(), :production)

      context "when using the correct base sends URL" do
        let :override_base_uri, do: Application.get_env(:textex, :base_sends_uri)

        context "with a valid SMS message" do
          let :sms_message do
            %SmsMessage{
              phone_number: real_valid_phone_number(),
              message:      "This is a test from ACOP server HttpClientSpec",
            }
          end
          let :cassette, do: "sms_message_send_single_success"

          it do: is_expected() |> to(eq(sms_message_success_result()))
        end

        context "with an invalid phone number" do
          let :sms_message do
            %SmsMessage{
              phone_number: real_invalid_phone_number(),
              message:      "This is a test from ACOP server HttpClientSpec",
            }
          end
          let :cassette, do: "sms_message_send_single_invalid_phone_number_error_result"

          it do: is_expected() |> to(eq(incorrectly_formatted_phone_number_error_result()))
        end

        context "with an invalid message" do
          subject do: result()

          let :sms_message do
            %SmsMessage{
              phone_number: real_valid_phone_number(),
            }
          end
          let :cassette, do: "sms_message_send_single_invalid_message_or_subject_error_result"

          it do: is_expected() |> to(eq(invalid_message_or_subject_error_result()))
        end

        context "with insufficient credits" do
          let :sms_message do
            %SmsMessage {
              phone_number: real_valid_phone_number(),
              message: "This is a test from ACOP server HttpClientSpec",
            }
          end

          let :cassette, do: "sms_message_send_insufficient_funds_failure"

          it do: is_expected() |> to(eq(insufficient_credits_error_result()))
        end

        context "with a valid group" do

          let :sms_message do
            %SmsMessage{
              groups:  [test_group()],
              message: "This is a test from ACOP server HttpClientSpec",
            }
          end
          let :cassette, do: "sms_message_send_single_group_success"

          it do: is_expected() |> to(eq(sms_message_success_result()))
        end

        context "with an invalid group" do

          let :sms_message do
            %SmsMessage{
              groups:  [invalid_group()],
              message: "This is a test from ACOP server HttpClientSpec",
            }
          end
          let :cassette, do: "sms_message_send_invalid_group_error_result"

          it do: is_expected() |> to(eq(invalid_group_error_result()))
        end

        context "with a valid stamp_to_send" do

          with {:ok, datetime} <- DateTime.now("Etc/UTC"),
               {:ok, future}   <- DateTime.add(datetime, 300, :second),
               {:ok, unix}      <- DateTime.to_unix(future, :second) do

            let :sms_message do
              %SmsMessage {
                phone_number:  real_valid_phone_number(),
                message:       "This is a test from ACOP server HttpClientSpec",
                stamp_to_send: unix
              }
            end
            let :cassette, do: "sms_message_send_valid_stamp_to_send_success_result"

            it do: is_expected() |> to(eq(sms_message_success_result()))
          end

        end

        context "with an invalid stamp_to_send" do

          let :stamp, do: "yesterday"
          let :sms_message do
            %SmsMessage {
              phone_number:  real_valid_phone_number(),
              message:       "This is a test from ACOP server HttpClientSpec",
              stamp_to_send: stamp
            }
          end
          let :cassette, do: "sms_message_send_invalid_stamp_to_send_error_result"

          it do: is_expected() |> to(eq(invalid_stamp_error_result()))
        end
      end
    end
  end
end
