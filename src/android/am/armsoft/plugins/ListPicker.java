package am.armsoft.plugins;

import java.util.ArrayList;
import java.util.List;

import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.util.Log;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.PluginResult;

/**
 * This class provides a service.
 */
public class ListPicker extends CordovaPlugin {
    /**
     * Private Member;
     */
    private String m_title;
    private JSONArray m_selectedValues;
    private static int MAX_NUMBER_OF_COLUMNS = 3;

    private abstract class CallbackInterface {
        abstract void onSuccess();
    }

    /**
     * Constructor.
     */
    public ListPicker() {
    }

    /**
     * Executes the request and returns PluginResult.
     *
     * @param action        The action to execute.
     * @param args          JSONArry of arguments for the plugin.
     * @param callbackId    The callback id used when calling back into JavaScript.
     * @return              A PluginResult object with a status and message.
     */
    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        if (action.equals("showPicker")) {
            this.showPicker(args, callbackContext);
            return true;
        }
        return false;
    }

    // --------------------------------------------------------------------------
    // LOCAL METHODS
    // --------------------------------------------------------------------------

    public void showPicker(final JSONArray data, final CallbackContext callbackContext) throws JSONException {
    
        final CordovaInterface cordova = this.cordova;
        
        final JSONObject options = data.getJSONObject(0);
        final String selectedValue = options.getString("selectedValue");
        final JSONArray items = options.getJSONArray("items");
        m_selectedValues = new JSONArray("[" + selectedValue + "]");
        m_title = options.getString("title");

        // Get the texts to display
        int index = -1;
        List<String> list = new ArrayList<String>();
        for(int i = 0; i < items.length(); i++) {
            JSONObject item = items.getJSONObject(i);
            list.add(item.getString("text"));
            if (selectedValue.equals(item.getString("value"))) {
              index = i;
            }
        }
        final CharSequence[] texts = list.toArray(new CharSequence[list.size()]);
        final int selectedIndex = index;
        
        // Create and show the alert dialog
        Runnable runnable = new Runnable() {
            public void run() {
                AlertDialog.Builder builder = new AlertDialog.Builder(cordova.getActivity());
                
                // Set dialog properties
                builder.setTitle(m_title);
                builder.setCancelable(true);
                builder.setSingleChoiceItems(texts, selectedIndex, new DialogInterface.OnClickListener() {
                    public void onClick(final DialogInterface dialog, int index) {
                        try {
                            final JSONObject selectedItem = items.getJSONObject(index);
                            m_selectedValues = new JSONArray("[" + selectedItem.getString("value") + "]");

                            try {
                                final JSONObject next = selectedItem.getJSONObject("next");
                                showListPickerRecursive(next, 1, callbackContext, new CallbackInterface() {
                                    public void onSuccess() {
                                        dialog.dismiss();
                                    }
                                });
                            } catch (JSONException e) {
                                callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, m_selectedValues));
                                dialog.dismiss();
                            }
                        }
                        catch (JSONException e) {
                            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.JSON_EXCEPTION));
                        }
                    }
                });
                builder.setOnCancelListener(new  DialogInterface.OnCancelListener() { 
                    public void onCancel(DialogInterface dialog) { 
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR));
                    } 
                }); 
                
                // Show alert dialog
                AlertDialog alert = builder.create();
                alert.getWindow().getAttributes().windowAnimations = android.R.style.Animation_Dialog;
                alert.show(); 
            }
        };
        this.cordova.getActivity().runOnUiThread(runnable);
    }

    private void showListPickerRecursive(final JSONObject data, final int depth, final CallbackContext callbackContext, final CallbackInterface callbackInterface) throws JSONException {
        if (depth >= MAX_NUMBER_OF_COLUMNS) {
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, m_selectedValues));
            callbackInterface.onSuccess();
            return;
        }

        String title;
        final JSONArray items;
        try {
            items = data.getJSONArray("items");
        } catch (JSONException e) {
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, m_selectedValues));
            callbackInterface.onSuccess();
            return;
        }
        try {
            title = data.getString("title");
        } catch (JSONException e) {
            title = m_title;
        }

        List<String> list = new ArrayList<String>();
        for (int i = 0; i < items.length(); i++) {
            JSONObject item = items.getJSONObject(i);
            list.add(item.getString("text"));
        }

        final CharSequence[] texts = list.toArray(new CharSequence[list.size()]);

        AlertDialog.Builder builder = new AlertDialog.Builder(cordova.getActivity());
        builder.setTitle(title);
        builder.setCancelable(true);
        builder.setSingleChoiceItems(texts, 0, new DialogInterface.OnClickListener() {
            public void onClick(final DialogInterface dialog, int index) {
                try {
                    final JSONObject selectedItem = items.getJSONObject(index);
                    final String selectedValue = selectedItem.getString("value");

                    m_selectedValues.put(selectedValue);

                    try {
                        final JSONObject next = selectedItem.getJSONObject("next");
                        showListPickerRecursive(next, depth + 1, callbackContext, new CallbackInterface() {
                            public void onSuccess() {
                                dialog.dismiss();
                                callbackInterface.onSuccess();
                            }
                        });
                    } catch (JSONException e) {
                        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, m_selectedValues));
                        dialog.dismiss();
                        callbackInterface.onSuccess();
                    }
                } catch (JSONException e) {
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.JSON_EXCEPTION));
                }
            }
        });
        builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
            public void onCancel(DialogInterface dialog) {
                m_selectedValues.remove(m_selectedValues.length() - 1);
            }
        });

        AlertDialog alert = builder.create();
        alert.getWindow().getAttributes().windowAnimations = android.R.style.Animation_Dialog;
        alert.show();
    }

}