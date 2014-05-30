package org.xtendroid.xtendroidtest.test;

import android.test.ActivityInstrumentationTestCase2;
import android.view.View;
import android.widget.TextView;
import junit.framework.Assert;
import org.eclipse.xtext.xbase.lib.Exceptions;
import org.xtendroid.xtendroidtest.MainActivity;
import org.xtendroid.xtendroidtest.R;

@SuppressWarnings("all")
public class ActivityAnnotation extends ActivityInstrumentationTestCase2<MainActivity> {
  public ActivityAnnotation() {
    super(MainActivity.class);
  }
  
  public void testAnnotation() {
    try {
      MainActivity _activity = this.getActivity();
      final TextView annotationTv = ((MainActivity) _activity).getMainHello();
      MainActivity _activity_1 = this.getActivity();
      View _findViewById = _activity_1.findViewById(R.id.main_hello);
      final TextView tv = ((TextView) _findViewById);
      MainActivity _activity_2 = this.getActivity();
      String _string = _activity_2.getString(R.string.hello_world);
      CharSequence _text = tv.getText();
      Assert.assertEquals(_string, _text);
      MainActivity _activity_3 = this.getActivity();
      final Runnable _function = new Runnable() {
        public void run() {
          annotationTv.setText("Testing");
          CharSequence _text = annotationTv.getText();
          CharSequence _text_1 = tv.getText();
          Assert.assertEquals(_text, _text_1);
        }
      };
      _activity_3.runOnUiThread(_function);
      Thread.sleep(1000);
    } catch (Throwable _e) {
      throw Exceptions.sneakyThrow(_e);
    }
  }
}
